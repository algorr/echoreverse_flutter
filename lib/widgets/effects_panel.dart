import 'package:flutter/material.dart';
import '../models/app_models.dart';

/// Effects selection panel overlay
class EffectsPanel extends StatelessWidget {
  final EffectType selectedEffect;
  final ValueChanged<EffectType> onEffectSelected;
  final VoidCallback onClose;

  const EffectsPanel({
    super.key,
    required this.selectedEffect,
    required this.onEffectSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final effects = [
      // Original effects
      _EffectItem(EffectType.none, Icons.auto_awesome, 'Clean'),
      _EffectItem(EffectType.robot, Icons.smart_toy, 'Robot'),
      _EffectItem(EffectType.chipmunk, Icons.cruelty_free, 'Chipmunk'),
      _EffectItem(EffectType.demon, Icons.whatshot, 'Demon'),
      _EffectItem(EffectType.echo, Icons.waves, 'Cosmos'),
      _EffectItem(EffectType.underwater, Icons.water_drop, 'Deep Sea'),
      _EffectItem(EffectType.radio, Icons.radio, 'Radio'),
      _EffectItem(EffectType.ghost, Icons.blur_on, 'Ghost'),
      // Fun effects
      _EffectItem(EffectType.alien, Icons.rocket_launch, 'Alien'),
      _EffectItem(EffectType.drunk, Icons.local_bar, 'Drunk'),
      _EffectItem(EffectType.helium, Icons.bubble_chart, 'Helium'),
      _EffectItem(EffectType.giant, Icons.fitness_center, 'Giant'),
      _EffectItem(EffectType.whisper, Icons.volume_off, 'Whisper'),
      _EffectItem(EffectType.megaphone, Icons.campaign, 'Megaphone'),
      // Atmospheric effects
      _EffectItem(EffectType.cave, Icons.landscape, 'Cave'),
      _EffectItem(EffectType.telephone, Icons.phone_callback, 'Telephone'),
      _EffectItem(EffectType.stadium, Icons.stadium, 'Stadium'),
      _EffectItem(EffectType.horror, Icons.psychology, 'Horror'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'VOICE MODULATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.grey[500],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[400],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),

          // Effects Grid (Scrollable)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: effects.map((effect) {
                  final isSelected = selectedEffect == effect.type;
                  return GestureDetector(
                    onTap: () => onEffectSelected(effect.type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 70,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF22D3EE).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF22D3EE)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF22D3EE,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 15,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            effect.icon,
                            size: 20,
                            color: isSelected
                                ? const Color(0xFF22D3EE)
                                : Colors.grey[500],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            effect.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? const Color(0xFF22D3EE)
                                  : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EffectItem {
  final EffectType type;
  final IconData icon;
  final String label;

  _EffectItem(this.type, this.icon, this.label);
}
