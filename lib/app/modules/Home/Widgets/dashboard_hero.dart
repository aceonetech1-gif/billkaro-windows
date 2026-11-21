import 'package:billkaro/config/config.dart';
import 'package:intl/intl.dart';

class DashboardHero extends StatelessWidget {
  const DashboardHero({
    super.key,
    required this.businessName,
    required this.todaySales,
    required this.yesterdaySales,
    required this.todayOrders,
    required this.yesterdayOrders,
    this.onNewOrder,
    this.newOrderLabel = 'New Order',
  });

  final String businessName;
  final double todaySales;
  final double yesterdaySales;
  final int todayOrders;
  final int yesterdayOrders;
  final VoidCallback? onNewOrder;
  final String newOrderLabel;

  static final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final avg = todayOrders > 0 ? todaySales / todayOrders : 0.0;
    final change = yesterdaySales > 0
        ? (todaySales - yesterdaySales) / yesterdaySales * 100
        : null;
    final date = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 720;
        final stats = [
          _Stat('Orders', '$todayOrders', 'Yesterday $yesterdayOrders'),
          _Stat('Avg. order', _money.format(avg), 'Per bill today'),
          _Stat(
            'Yesterday',
            _money.format(yesterdaySales),
            'Total sales',
          ),
        ];

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -60,
                top: -80,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColor.primary.withOpacity(0.25),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(wide ? 28 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                date.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                businessName.isEmpty
                                    ? _greeting
                                    : '$_greeting, $businessName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: wide ? 22 : 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onNewOrder != null)
                          FilledButton.icon(
                            onPressed: onNewOrder,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0F172A),
                              padding: EdgeInsets.symmetric(
                                horizontal: wide ? 18 : 12,
                                vertical: wide ? 14 : 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              newOrderLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: wide ? 28 : 20),
                    const Text(
                      "Today's revenue",
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          _money.format(todaySales),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: wide ? 40 : 32,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        if (change != null) _ChangeChip(change: change),
                      ],
                    ),
                    SizedBox(height: wide ? 24 : 18),
                    Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.08),
                    ),
                    SizedBox(height: wide ? 20 : 16),
                    Row(
                      children: [
                        for (var i = 0; i < stats.length; i++) ...[
                          if (i > 0)
                            Container(
                              width: 1,
                              height: 36,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              color: Colors.white.withOpacity(0.08),
                            ),
                          Expanded(child: _statView(stats[i], wide)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statView(_Stat s, bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            s.value,
            style: TextStyle(
              color: Colors.white,
              fontSize: wide ? 19 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (wide) ...[
          const SizedBox(height: 2),
          Text(
            s.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.caption);
  final String label;
  final String value;
  final String caption;
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({required this.change});
  final double change;

  @override
  Widget build(BuildContext context) {
    final up = change >= 0;
    final color = up ? const Color(0xFF34D399) : const Color(0xFFF87171);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            '${up ? '+' : ''}${change.toStringAsFixed(1)}% vs yesterday',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
