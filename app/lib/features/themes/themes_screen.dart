import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/theme_controller.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/hud_label.dart';
import '../../core/widgets/yazzoki_button.dart';

/// "Temas" — the theme picker.
///
/// Flow (deliberately two-step, like a purchase):
///   1. pick the brightness (Claro / Escuro / Sistema);
///   2. pick one of the catalog themes (preview card + SELECT);
///   3. CONFIRMAR applies it — and asks whether it should also be shown to
///      OTHER users on the profile ("Aplicar tema de perfil a outros
///      usuários?"), which is the only part that touches the server.
class ThemesScreen extends StatefulWidget {
  const ThemesScreen({super.key});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  /// The theme the user SELECTED but has not confirmed yet.
  late String _draftId;

  @override
  void initState() {
    super.initState();
    _draftId = ThemeController.instance.themeId;
  }

  void _confirm() {
    final controller = ThemeController.instance;
    final state = AppStateScope.of(context);
    // Apply locally (instant) and, when the switch is on, push the id to the
    // server so OTHER users see this profile in the chosen theme.
    controller.setThemeId(_draftId);
    state.syncProfileTheme(
      apply: controller.applyToProfile,
      themeId: _draftId,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tema ${themeById(_draftId).label} aplicado.')),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    return Scaffold(
      backgroundColor: AppColors.absoluteBlack,
      appBar: AppBar(
        backgroundColor: AppColors.absoluteBlack,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.techWhite),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Temas', style: AppTextStyles.title.copyWith(fontSize: 18)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.spaceLg,
            AppDimensions.spaceSm,
            AppDimensions.spaceLg,
            AppDimensions.spaceHuge,
          ),
          children: [
            // ── 1) brilho ─────────────────────────────────────
            Text('MODO', style: AppTextStyles.hud),
            const SizedBox(height: AppDimensions.spaceSm),
            _BrightnessRow(controller: controller),
            const SizedBox(height: AppDimensions.spaceXl),

            // ── 2) catálogo ───────────────────────────────────
            Text('ESCOLHA O TEMA', style: AppTextStyles.hud),
            const SizedBox(height: AppDimensions.spaceMd),
            for (final theme in yazzokiThemes) ...[
              _ThemeCard(
                theme: theme,
                selected: theme.id == _draftId,
                onSelect: () => setState(() => _draftId = theme.id),
              ),
              const SizedBox(height: AppDimensions.spaceMd),
            ],
            const SizedBox(height: AppDimensions.spaceMd),

            // ── 3) perfil global ──────────────────────────────
            _GlobalToggle(controller: controller),
            const SizedBox(height: AppDimensions.spaceXl),

            YazzokiButton(
              label: 'CONFIRMAR TEMA',
              icon: Icons.check_rounded,
              expanded: true,
              onPressed: _confirm,
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            Text(
              'O tema muda só o visual do app. Suas fotos, banner e '
              'publicações continuam iguais.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Claro / Escuro / Sistema — moved here from the settings menu.
class _BrightnessRow extends StatelessWidget {
  const _BrightnessRow({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    const options = [
      (YazzokiThemeMode.light, 'Claro', Icons.light_mode_rounded),
      (YazzokiThemeMode.dark, 'Escuro', Icons.dark_mode_rounded),
      (YazzokiThemeMode.system, 'Sistema', Icons.smartphone_rounded),
    ];
    return Row(
      children: [
        for (final (mode, label, icon) in options) ...[
          Expanded(
            child: _BrightnessButton(
              icon: icon,
              label: label,
              active: controller.mode == mode,
              onTap: () => controller.setMode(mode),
            ),
          ),
          if (mode != YazzokiThemeMode.system)
            const SizedBox(width: AppDimensions.spaceSm),
        ],
      ],
    );
  }
}

class _BrightnessButton extends StatelessWidget {
  const _BrightnessButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.techWhite : AppColors.holographicBlue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryBlue : AppColors.bluishBlack,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: active ? AppColors.primaryBlue : AppColors.deepBlue,
            width: AppDimensions.borderWidthActive,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(height: AppDimensions.spaceXs),
            Text(label, style: AppTextStyles.label.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

/// One catalog entry: the preview image (Home/Chat/Profile in that theme),
/// the name, and a SELECT action. The card itself is tappable too.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.onSelect,
  });

  final YazzokiTheme theme;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bluishBlack,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.deepBlue,
            width: selected
                ? AppDimensions.borderWidthActive
                : AppDimensions.borderWidthThin,
          ),
        ),
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: AspectRatio(
                aspectRatio: 684 / 466,
                child: Image.asset(
                  'assets/themes/theme_${theme.id}.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.nightBlue,
                    alignment: Alignment.center,
                    child: Text('Preview indisponível',
                        style: AppTextStyles.caption),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(theme.label,
                          style: AppTextStyles.h3.copyWith(fontSize: 16)),
                      Text(theme.subtitle, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                if (selected)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: AppColors.primaryBlue, size: 18),
                      const SizedBox(width: AppDimensions.spaceXs),
                      Text('SELECIONADO',
                          style: AppTextStyles.hud
                              .copyWith(color: AppColors.primaryBlue)),
                    ],
                  )
                else
                  Text('SELECIONAR',
                      style:
                          AppTextStyles.hud.copyWith(color: AppColors.accentInk)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Aplicar tema de perfil a outros usuários?" — the only server-backed part.
class _GlobalToggle extends StatelessWidget {
  const _GlobalToggle({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bluishBlack,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.deepBlue),
      ),
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      child: Row(
        children: [
          Icon(Icons.public_rounded, color: AppColors.accentInk, size: 22),
          const SizedBox(width: AppDimensions.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aplicar tema de perfil a outros usuários?',
                    style: AppTextStyles.body),
                const SizedBox(height: 2),
                Text(
                  'Quando ligado, quem abrir o SEU perfil vê o tema que você '
                  'escolheu no cabeçalho.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Switch(
            value: controller.applyToProfile,
            onChanged: (v) => controller.setApplyToProfile(v),
          ),
        ],
      ),
    );
  }
}

/// Opens the Temas screen.
Future<void> openThemes(BuildContext context) {
  return Navigator.of(context).pushNamed(AppRoutes.themes);
}

/// The settings-menu entry that leads to the Temas screen.
class ThemesEntryTile extends StatelessWidget {
  const ThemesEntryTile({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => InkWell(
        onTap: () => openThemes(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceSm,
            vertical: AppDimensions.spaceLg,
          ),
          child: Row(
            children: [
              Icon(Icons.palette_rounded,
                  color: AppColors.holographicBlue, size: 22),
              const SizedBox(width: AppDimensions.spaceMd),
              Expanded(child: Text('Temas', style: AppTextStyles.body)),
              HudLabel(text: controller.theme.label),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.holographicBlue, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
