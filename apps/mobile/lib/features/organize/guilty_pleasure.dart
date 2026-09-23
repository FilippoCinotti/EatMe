import 'package:flutter/material.dart';

import '../../core/localization.dart';
import '../../design_system/widgets.dart';

Future<String?> showGuiltyPleasureSheet(
  BuildContext context, {
  bool active = false,
}) => showModalBottomSheet<String>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => GuiltyPleasureSheet(active: active),
);

class GuiltyPleasureSheet extends StatefulWidget {
  const GuiltyPleasureSheet({super.key, required this.active});
  final bool active;

  @override
  State<GuiltyPleasureSheet> createState() => _GuiltyPleasureSheetState();
}

class _GuiltyPleasureSheetState extends State<GuiltyPleasureSheet> {
  String scope = 'meal';

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      18,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const EatMeIcon(EatMeGlyph.sparkles, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t('guilty_pleasure'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          context.t(
            widget.active
                ? 'guilty_pleasure_active_body'
                : 'guilty_pleasure_body',
          ),
        ),
        const SizedBox(height: 18),
        if (!widget.active)
          RadioGroup<String>(
            groupValue: scope,
            onChanged: (value) => setState(() => scope = value ?? scope),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t('guilty_pleasure_scope'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                RadioListTile<String>(
                  value: 'meal',
                  title: Text(context.t('this_meal')),
                ),
                RadioListTile<String>(
                  value: 'day',
                  title: Text(context.t('today')),
                ),
              ],
            ),
          ),
        StatusNote(text: context.t('guilty_pleasure_safety')),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, widget.active ? 'off' : scope),
          child: Text(
            context.t(
              widget.active
                  ? 'turn_off_guilty_pleasure'
                  : 'turn_on_guilty_pleasure',
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('cancel')),
        ),
      ],
    ),
  );
}
