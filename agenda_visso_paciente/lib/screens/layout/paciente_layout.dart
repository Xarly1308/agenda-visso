import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class PacienteLayout extends StatelessWidget {
  final int currentStep;
  final List<String> steps;
  final Widget child;
  final VoidCallback? onBack;

  const PacienteLayout({
    super.key,
    required this.currentStep,
    required this.steps,
    required this.child,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          // Desktop Layout
          return Scaffold(
            backgroundColor: AppTheme.surface,
            body: Row(
              children: [
                _buildSidebar(context),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(context, isDesktop: true),
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          child: SingleChildScrollView(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1000),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile Layout
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: AppTheme.surface,
              leading: onBack != null
                  ? const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.arrow_back),
                    )
                  : null,
              leadingWidth: onBack != null ? 40 : null,
              title: Image.asset(
                'assets/visso_logo.png',
                height: 32,
                errorBuilder: (context, error, stackTrace) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility, color: AppTheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text('VISSO', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ],
                ),
              ),
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(onBack != null ? 90 : 60),
                child: Column(
                  children: [
                    if (onBack != null)
                      SizedBox(
                        height: 30,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back, size: 16),
                            label: const Text('Volver'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ),
                    _buildMobileStepper(context),
                  ],
                ),
              ),
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: child,
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 280,
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Image.asset(
              'assets/visso_logo.png',
              height: 48,
              errorBuilder: (context, error, stackTrace) => Row(
                children: [
                  const Icon(Icons.visibility, color: AppTheme.primary, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'VISSO',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
            child: Text(
              'Reserva tu\nCita',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppTheme.primaryContainer,
                    fontSize: 32,
                    height: 1.2,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Paso ${currentStep + 1} de ${steps.length}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final isCompleted = index < currentStep;
                final isActive = index == currentStep;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.primaryContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle : (isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                          color: isActive ? Colors.white : (isCompleted ? AppTheme.primaryContainer : Colors.grey.shade400),
                          size: 20,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          steps[index],
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: isActive ? Colors.white : (isCompleted ? AppTheme.onSurface : Colors.grey.shade600),
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, {required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: isDesktop ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
        children: [
          if (onBack != null && isDesktop) ...[
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Volver'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            ),
            const Spacer(),
          ],
          TextButton(
            onPressed: () {},
            child: const Text('Reserva', style: TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 16),
          TextButton(
            onPressed: () {},
            child: Text('Servicios', style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
          ),
          const SizedBox(width: 16),
          TextButton(
            onPressed: () {},
            child: Text('Sedes', style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStepper(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: List.generate(steps.length, (i) {
          final activo = i == currentStep;
          final completado = i < currentStep;
          return Expanded(
            child: Row(
              children: [
                if (i > 0) Expanded(child: Container(height: 2, color: completado ? AppTheme.primaryContainer : Colors.grey.shade300)),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: completado ? AppTheme.primaryContainer : (activo ? AppTheme.secondaryContainer : Colors.grey.shade200),
                  child: Text(
                    completado ? '✓' : '${i + 1}',
                    style: TextStyle(
                      fontSize: 12, 
                      color: completado ? Colors.white : (activo ? AppTheme.primaryContainer : Colors.grey.shade500),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (i < steps.length - 1) Expanded(child: Container(height: 2, color: completado ? AppTheme.primaryContainer : Colors.grey.shade300)),
              ],
            ),
          );
        }),
      ),
    );
  }
}
