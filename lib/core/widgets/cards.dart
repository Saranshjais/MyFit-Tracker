import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

const pagePadding = EdgeInsets.fromLTRB(16, 8, 16, 24);

/// Bordered surface used for most content blocks.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.highlighted = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Green outline, e.g. for today's day in the week plan.
  final bool highlighted;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = BorderRadius.circular(12);
    return Material(
      color: color ?? p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: highlighted ? p.accent : p.border, width: highlighted ? 1.4 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small uppercase label above titles ("TODAY'S WORKOUT").
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color));
}

/// Title block at the top of each main tab.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.kicker, this.subtitle, this.trailing});
  final String title;
  final String? kicker;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null) ...[Kicker(kicker!), const SizedBox(height: 6)],
                Text(title, style: t.headlineSmall),
                if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: t.bodySmall)],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.only(top: 20, bottom: 10),
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17.5))),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(action!),
          ),
      ],
    ),
  );
}

/// Rounded tinted square holding an icon (settings rows, food and exercise thumbnails).
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.color, this.size = 44, this.iconSize});
  final IconData icon;
  final Color? color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.accentText;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(size * 0.26)),
      child: Icon(icon, color: c, size: iconSize ?? size * 0.52),
    );
  }
}

/// Big number with a label, e.g. calories or session volume.
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, this.caption, this.valueColor, this.onTap});
  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(label),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: t.headlineSmall?.copyWith(color: valueColor ?? context.palette.accentText, fontSize: 24),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

/// Small coloured label ("Sample", "Estimate", "Custom").
class Badge2 extends StatelessWidget {
  const Badge2(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}

/// Settings-style row with an icon tile, title, subtitle and chevron.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconTile(icon: icon, color: color, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 15)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Groups rows in one card with dividers between them.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: context.palette.border),
          children[i],
        ],
      ],
    ),
  );
}
