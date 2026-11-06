import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ScreenIntro extends StatelessWidget {
  const ScreenIntro({super.key, required this.icon, required this.title, required this.description, this.actions = const []});

  final IconData icon;
  final String title, description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(builder: (context, limits) {
        final identity = Row(children: [
          ScreenIcon(icon),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
          ])),
        ]);
        if (actions.isEmpty) return identity;
        final controls = Wrap(spacing: 8, runSpacing: 8, children: actions);
        if (limits.maxWidth < 720) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            identity, const SizedBox(height: 12), controls,
          ]);
        }
        return Row(children: [Expanded(child: identity), const SizedBox(width: 16), controls]);
      }),
    ),
  );
}

class ScreenIcon extends StatelessWidget {
  const ScreenIcon(this.icon, {super.key, this.color = AppColors.accent});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 42, height: 42,
    decoration: BoxDecoration(
      color: color.withOpacity(.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 22),
  );
}

class ScreenEmpty extends StatelessWidget {
  const ScreenEmpty({super.key, required this.icon, required this.title, required this.hint, this.action});
  final IconData icon;
  final String title, hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(child: Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScreenIcon(icon),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 5),
          Text(hint, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      ),
    )),
  );
}

class AccessFrame extends StatelessWidget {
  const AccessFrame({super.key, required this.title, required this.caption, required this.icon, required this.child});
  final String title, caption;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight, end: Alignment.bottomLeft,
          colors: [Color(0xFF192F3B), AppColors.background, AppColors.background],
        ),
      ),
      child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(width: 470, child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                ScreenIcon(icon),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  Text(caption, style: Theme.of(context).textTheme.bodySmall),
                ])),
              ]),
              const SizedBox(height: 24),
              child,
            ]),
          ),
        )),
      )),
    ),
  );
}
