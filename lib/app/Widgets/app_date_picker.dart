import 'package:billkaro/config/app_scroll_behavior.dart';
import 'package:billkaro/config/config.dart';
import 'package:intl/intl.dart';

const _accent = AppColor.secondaryPrimary;

ThemeData _pickerTheme(ThemeData base) {
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: _accent,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF111827),
    ),
    datePickerTheme: DatePickerThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      headerBackgroundColor: _accent.withValues(alpha: 0.1),
      headerForegroundColor: const Color(0xFF111827),
      todayForegroundColor: WidgetStateProperty.all(_accent),
      todayBackgroundColor: WidgetStateProperty.all(
        _accent.withValues(alpha: 0.08),
      ),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        if (states.contains(WidgetState.disabled)) {
          return Colors.grey.shade400;
        }
        return const Color(0xFF111827);
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _accent;
        return null;
      }),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

Widget _themed(BuildContext context, Widget child) {
  return Theme(data: _pickerTheme(Theme.of(context)), child: child);
}

AppLocalizations? _loc(BuildContext context) => AppLocalizations.of(context);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _clampDate(DateTime date, DateTime first, DateTime last) {
  final d = _dateOnly(date);
  if (d.isBefore(first)) return first;
  if (d.isAfter(last)) return last;
  return d;
}

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  String? cancelText,
  String? confirmText,
  bool useRootNavigator = true,
}) {
  final loc = _loc(context);
  return showDatePicker(
    context: context,
    useRootNavigator: useRootNavigator,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText ?? loc?.select_date ?? 'Select Date',
    cancelText: cancelText ?? loc?.cancel ?? 'Cancel',
    confirmText: confirmText ?? loc?.ok ?? 'OK',
    initialEntryMode: DatePickerEntryMode.calendarOnly,
    builder: (ctx, child) =>
        child == null ? const SizedBox.shrink() : _themed(ctx, child),
  );
}

/// Compact dialog date-range picker with month arrows and year picker.
Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
  String? helpText,
  String? cancelText,
  String? confirmText,
  bool useRootNavigator = true,
}) {
  final loc = _loc(context);
  final first = _dateOnly(firstDate);
  final last = _dateOnly(lastDate);

  return showDialog<DateTimeRange>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (dialogContext) {
      return _themed(
        dialogContext,
        _AppDateRangeDialog(
          firstDate: first,
          lastDate: last,
          initialDateRange: initialDateRange,
          helpText: helpText ?? loc?.select_date_range ?? 'Select Date Range',
          cancelText: cancelText ?? loc?.cancel ?? 'Cancel',
          confirmText: confirmText ?? loc?.ok ?? 'OK',
        ),
      );
    },
  );
}

Future<DateTime?> showAppDatePickerFromGet({
  BuildContext? context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  String? cancelText,
  String? confirmText,
  bool useRootNavigator = true,
}) {
  final pickerContext = context ?? Get.context;
  if (pickerContext == null) return Future.value();
  return showAppDatePicker(
    context: pickerContext,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    cancelText: cancelText,
    confirmText: confirmText,
    useRootNavigator: useRootNavigator,
  );
}

Future<DateTimeRange?> showAppDateRangePickerFromGet({
  BuildContext? context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
  String? helpText,
  String? cancelText,
  String? confirmText,
  bool useRootNavigator = true,
}) {
  final pickerContext = context ?? Get.context;
  if (pickerContext == null) return Future.value();
  return showAppDateRangePicker(
    context: pickerContext,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDateRange: initialDateRange,
    helpText: helpText,
    cancelText: cancelText,
    confirmText: confirmText,
    useRootNavigator: useRootNavigator,
  );
}

class _AppDateRangeDialog extends StatefulWidget {
  const _AppDateRangeDialog({
    required this.firstDate,
    required this.lastDate,
    required this.helpText,
    required this.cancelText,
    required this.confirmText,
    this.initialDateRange,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initialDateRange;
  final String helpText;
  final String cancelText;
  final String confirmText;

  @override
  State<_AppDateRangeDialog> createState() => _AppDateRangeDialogState();
}

class _AppDateRangeDialogState extends State<_AppDateRangeDialog> {
  static final _fmt = DateFormat('dd MMM yyyy');

  late DateTime? _start;
  late DateTime? _end;
  late DateTime _focusedDay;
  bool _pickingStart = true;
  int _calendarKey = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDateRange;
    _start = initial != null ? _dateOnly(initial.start) : null;
    _end = initial != null ? _dateOnly(initial.end) : null;
    _focusedDay = _clampDate(
      _start ?? widget.lastDate,
      widget.firstDate,
      widget.lastDate,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onDaySelected(DateTime day) {
    final selected = _dateOnly(day);
    setState(() {
      if (_pickingStart) {
        _start = selected;
        if (_end != null && _end!.isBefore(_start!)) _end = null;
        _pickingStart = false;
      } else {
        if (_start != null && selected.isBefore(_start!)) {
          _end = _start;
          _start = selected;
        } else {
          _end = selected;
        }
        _pickingStart = true;
      }
      _focusedDay = selected;
      _calendarKey++;
    });
  }

  void _selectSide({required bool start}) {
    setState(() {
      _pickingStart = start;
      final focus = start ? (_start ?? _focusedDay) : (_end ?? _start ?? _focusedDay);
      _focusedDay = _clampDate(focus, widget.firstDate, widget.lastDate);
      _calendarKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _start != null && _end != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ScrollConfiguration(
        behavior: const AppScrollBehavior(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            interactive: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.helpText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _RangeSideChip(
                            label: 'From',
                            value: _start == null ? '—' : _fmt.format(_start!),
                            selected: _pickingStart,
                            onTap: () => _selectSide(start: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RangeSideChip(
                            label: 'To',
                            value: _end == null ? '—' : _fmt.format(_end!),
                            selected: !_pickingStart,
                            onTap: () => _selectSide(start: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CalendarDatePicker(
                      key: ValueKey(_calendarKey),
                      initialDate: _focusedDay,
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                      currentDate: DateTime.now(),
                      onDateChanged: _onDaySelected,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(widget.cancelText),
                        ),
                        TextButton(
                          onPressed: canConfirm
                              ? () => Navigator.of(context).pop(
                                    DateTimeRange(start: _start!, end: _end!),
                                  )
                              : null,
                          child: Text(widget.confirmText),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RangeSideChip extends StatelessWidget {
  const _RangeSideChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? _accent.withValues(alpha: 0.12)
          : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? _accent : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? _accent : const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
