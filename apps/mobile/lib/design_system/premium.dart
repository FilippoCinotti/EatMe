import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/localization.dart';
import 'food_image.dart';

/// Editorial hierarchy shared by the four decision-oriented destinations.
class EditorialHeader extends StatelessWidget {
  const EditorialHeader({super.key, required this.eyebrow, required this.title, required this.subtitle, this.actions = const [], this.art});
  final String eyebrow, title, subtitle;
  final List<Widget> actions;
  final Widget? art;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const EatMeWordmark(), const Spacer(), ...actions]),
    const SizedBox(height: 26),
    Text(eyebrow.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 2.2, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height: 8),
    if (art == null) Text(title, style: Theme.of(context).textTheme.displaySmall)
    else Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.displaySmall)), const SizedBox(width: 12), SizedBox(width: 82, height: 100, child: art)]),
    const SizedBox(height: 8),
    Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height: 24),
  ]);
}

class EatMeWordmark extends StatelessWidget {
  const EatMeWordmark({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) => Semantics(label: context.t('eatme'), child: ExcludeSemantics(child: Row(mainAxisSize: MainAxisSize.min, children: [
    Text(context.t('eatme'), style: TextStyle(fontFamily: 'EatMeDisplay', fontWeight: FontWeight.w700, fontSize: large ? 52 : 30, height: 1, letterSpacing: -1, color: Theme.of(context).colorScheme.primary)),
    const SizedBox(width: 3), Icon(Icons.eco, size: large ? 28 : 19, color: Theme.of(context).colorScheme.primary),
  ])));
}

class RoundAction extends StatelessWidget {
  const RoundAction({super.key, required this.icon, required this.label, required this.onPressed, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(left: 8), child: IconButton.filledTonal(tooltip: label, onPressed: onPressed, style: IconButton.styleFrom(minimumSize: const Size(48,48), backgroundColor: primary ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainer, foregroundColor: primary ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface), icon: Icon(icon, size: 23)));
}

class SearchPill extends StatelessWidget {
  const SearchPill({super.key, required this.hint, this.onChanged, this.onFilter, this.onTap});
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilter, onTap;
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .12 : .035), blurRadius: 20, offset: const Offset(0,7))]), child: TextField(readOnly: onTap != null, onTap: onTap, onChanged: onChanged, decoration: InputDecoration(hintText: hint, fillColor: Colors.transparent, hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), prefixIcon: const Icon(Icons.search, size: 22), suffixIcon: onFilter == null ? null : IconButton(tooltip: context.t('filters'), onPressed: onFilter, icon: const Icon(Icons.tune, size: 22)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none))));
}

class InformationPanel extends StatelessWidget {
  const InformationPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.tinted = true});
  final Widget child;
  final EdgeInsets padding;
  final bool tinted;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: tinted ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .6) : Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(26)), child: child);
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final contrast = MediaQuery.highContrastOf(context);
    return DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? .28 : .08), blurRadius: 28, offset: const Offset(0,8))]), child: ClipRRect(borderRadius: BorderRadius.circular(32), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: contrast ? 0 : 20, sigmaY: contrast ? 0 : 20), child: DecoratedBox(decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: contrast ? 1 : dark ? .88 : .82), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white.withValues(alpha: contrast ? .8 : dark ? .12 : .8), width: 1)), child: child))));
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.icon, this.urgent = false, this.emphasis = false});
  final String label;
  final IconData? icon;
  final bool urgent, emphasis;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = urgent ? scheme.error : emphasis ? scheme.onPrimary : scheme.onSurfaceVariant;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: urgent ? scheme.errorContainer : emphasis ? scheme.primary : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 5)], Flexible(child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, height: 1.25)))]));
  }
}

class FoodPhotoCard extends StatelessWidget {
  const FoodPhotoCard({super.key, required this.id, required this.title, required this.subtitle, required this.onTap, this.photoId, this.badge, this.onAction, this.actionIcon = Icons.more_horiz, this.actionLabel, this.imageHeight = 144});
  final String id, title, subtitle;
  final String? photoId, actionLabel;
  final VoidCallback onTap;
  final VoidCallback? onAction;
  final IconData actionIcon;
  final Widget? badge;
  final double imageHeight;
  @override
  Widget build(BuildContext context) => Material(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(23), clipBehavior: Clip.antiAlias, child: InkWell(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Stack(children: [FoodImage(id: id, photoId: photoId, height: imageHeight, radius: 0, fallback: Icons.eco_outlined), if (badge != null) Positioned(left: 8, right: 8, bottom: 8, child: Align(alignment: Alignment.centerLeft, child: badge))]),
    Padding(padding: const EdgeInsets.fromLTRB(12,12,12,14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 5), Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), if (onAction != null) Align(alignment: Alignment.centerRight, child: IconButton(tooltip: actionLabel, icon: Icon(actionIcon), onPressed: onAction))])),
  ])));
}

class AdaptivePhotoGrid extends StatelessWidget {
  const AdaptivePhotoGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final columns = constraints.maxWidth >= 330 && MediaQuery.textScalerOf(context).scale(16) <= 23 ? 2 : 1;
    final width = (constraints.maxWidth - (columns-1)*14)/columns;
    return Wrap(spacing: 14, runSpacing: 16, children: [for (final child in children) SizedBox(width: width, child: child)]);
  });
}

class HorizontalFoodRail extends StatelessWidget {
  const HorizontalFoodRail({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final child in children) Padding(padding: const EdgeInsets.only(right: 12), child: SizedBox(width: MediaQuery.textScalerOf(context).scale(16) > 23 ? 210 : 146, child: child))]));
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.label, required this.foodId, required this.selected, required this.onTap});
  final String label, foodId;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(selected: selected, child: Material(color: selected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(20), child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: SizedBox(width: MediaQuery.textScalerOf(context).scale(16)>23 ? 130 : 96, child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [FoodImage(id:foodId,height:62,radius:14,fallback:Icons.eco_outlined), const SizedBox(height:8), Text(label,textAlign:TextAlign.center,style:Theme.of(context).textTheme.labelMedium)]))))));
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.title});
  final List<Widget> children;
  final String? title;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom:24), child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[if(title!=null) Padding(padding:const EdgeInsets.only(bottom:12),child:Text(title!,style:Theme.of(context).textTheme.titleLarge)), InformationPanel(tinted:false,padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),child:Column(children:children))]));
}

class SettingRow extends StatelessWidget {
  const SettingRow({super.key,required this.title,required this.icon,this.subtitle,this.onTap,this.trailing});
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListTile(contentPadding:const EdgeInsets.symmetric(vertical:7),leading:Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(14)),child:Icon(icon,size:22,color:Theme.of(context).colorScheme.primary)),title:Text(title,style:Theme.of(context).textTheme.titleMedium),subtitle:subtitle==null?null:Text(subtitle!,style:Theme.of(context).textTheme.bodySmall),trailing:trailing??(onTap==null?null:const Icon(Icons.chevron_right,size:18)),onTap:onTap);
}

class ShortcutTile extends StatelessWidget {
  const ShortcutTile({super.key,required this.title,required this.icon,required this.onTap});
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context)=>Material(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(24),child:InkWell(borderRadius:BorderRadius.circular(24),onTap:onTap,child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,size:28,color:Theme.of(context).colorScheme.primary),const SizedBox(height:18),Text(title,style:Theme.of(context).textTheme.titleMedium)]))));
}

/// Secondary navigation keeps actions and titles readable at larger text sizes.
class EatMeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EatMeAppBar({super.key, this.title, this.leading, this.actions});
  final Widget? title, leading;
  final List<Widget>? actions;
  @override
  Size get preferredSize => const Size.fromHeight(72);
  @override
  Widget build(BuildContext context) => SafeArea(bottom: false, child: SizedBox(height: 72, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [if (leading != null) leading! else if (Navigator.canPop(context)) IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back)), Expanded(child: title == null ? const EatMeWordmark() : Semantics(header: true, child: DefaultTextStyle(style: Theme.of(context).textTheme.titleLarge!, maxLines: 1, overflow: TextOverflow.ellipsis, child: title!))), ...?actions]))));
}
