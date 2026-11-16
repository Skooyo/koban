import 'package:material_ui/material_ui.dart';

/// Opens a modal bottom sheet that keeps clear of the system bars.
/// `useSafeArea` covers the top only, so the sheet adds the bottom inset itself:
/// the last row stays above the navigation bar. Every sheet of the app opens through this.
Future<T?> showKobanSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  useSafeArea: true,
  showDragHandle: showDragHandle,
  builder: (context) => SafeArea(top: false, child: builder(context)),
);
