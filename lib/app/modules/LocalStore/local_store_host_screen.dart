import 'package:billkaro/app/services/local_store/local_store_host_service.dart';
import 'package:billkaro/app/services/local_store/local_store_joined_staff.dart';
import 'package:billkaro/config/config.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shows LAN join QR + status while this PC is the store host.
class LocalStoreHostScreen extends StatelessWidget {
  const LocalStoreHostScreen({super.key});

  LocalStoreHostService get host {
    if (!Get.isRegistered<LocalStoreHostService>()) {
      Get.put(LocalStoreHostService(), permanent: true);
    }
    return Get.find<LocalStoreHostService>();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColor.backGroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          loc.local_store_host_screen_title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final running = host.isRunning.value;
          final ip = host.lanIp.value ?? '—';
          final port = host.port.value;
          final clients = host.joinedStaff.length;
          final payload = host.joinPayload ?? '';
          final err = host.lastError.value;
          final staff = host.joinedStaff.toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _statusCard(
                      running: running,
                      clients: clients,
                      err: err,
                      loc: loc,
                    ),
                    const Gap(16),
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              loc.local_store_scan_qr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Gap(6),
                            Text(
                              loc.local_store_same_wifi_hint,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Gap(16),
                            if (payload.isNotEmpty)
                              QrImageView(
                                data: payload,
                                size: 220,
                                backgroundColor: Colors.white,
                              )
                            else
                              const SizedBox(
                                height: 220,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            const Gap(16),
                            SelectableText(
                              '$ip:$port',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Gap(4),
                            Text(
                              '${loc.local_store_join_code}: ${host.joinToken.value}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const Gap(16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: payload.isEmpty
                                      ? null
                                      : () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: payload),
                                          );
                                          showSuccess(
                                            description:
                                                loc.local_store_link_copied,
                                          );
                                        },
                                  icon: const Icon(Icons.copy, size: 18),
                                  label: Text(loc.local_store_copy_link),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await host.regenerateJoinToken();
                                    showSuccess(
                                      description:
                                          loc.local_store_code_regenerated,
                                    );
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: Text(loc.local_store_new_code),
                                ),
                                if (!running)
                                  FilledButton.icon(
                                    onPressed: () async {
                                      try {
                                        await host.start();
                                      } catch (e) {
                                        showError(description: '$e');
                                      }
                                    },
                                    icon: const Icon(Icons.play_arrow),
                                    label: Text(loc.local_store_start_host),
                                  )
                                else
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      try {
                                        await host.setEnabled(false);
                                        showSuccess(
                                          description:
                                              loc.local_store_host_stopped_toast,
                                        );
                                      } catch (e) {
                                        showError(description: '$e');
                                      }
                                    },
                                    icon: const Icon(Icons.stop),
                                    label: Text(loc.local_store_stop_host),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(16),
                    _joinedStaffCard(loc: loc, staff: staff),
                    const Gap(16),
                    Text(
                      loc.local_store_host_howto,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _joinedStaffCard({
    required AppLocalizations loc,
    required List<LocalStoreJoinedStaff> staff,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_outlined, color: AppColor.primary, size: 22),
                const Gap(8),
                Expanded(
                  child: Text(
                    loc.local_store_joined_staff_title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${staff.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const Gap(10),
            if (staff.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  loc.local_store_joined_staff_empty,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              )
            else
              ...staff.map((s) => _staffTile(loc, s)),
          ],
        ),
      ),
    );
  }

  Widget _staffTile(AppLocalizations loc, LocalStoreJoinedStaff staff) {
    final via = staff.joinMethod == 'qr'
        ? loc.local_store_joined_via_qr
        : loc.local_store_joined_via_code;
    final time = DateFormat('hh:mm a').format(staff.joinedAt.toLocal());
    final subtitleParts = <String>[
      via,
      time,
      if (staff.platform != null && staff.platform!.isNotEmpty)
        staff.platform!,
      if (staff.remoteAddress != null && staff.remoteAddress!.isNotEmpty)
        staff.remoteAddress!,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: AppColor.primary.withValues(alpha: 0.12),
          child: Text(
            staff.displayName.trim().isNotEmpty
                ? staff.displayName.trim()[0].toUpperCase()
                : 'S',
            style: TextStyle(
              color: AppColor.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          staff.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitleParts.join(' · '),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: IconButton(
          tooltip: loc.local_store_remove_staff,
          onPressed: () => host.removeJoinedStaff(staff.deviceId),
          icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _statusCard({
    required bool running,
    required int clients,
    required String? err,
    required AppLocalizations loc,
  }) {
    final color = err != null && err.isNotEmpty
        ? Colors.orange
        : running
            ? Colors.green
            : Colors.grey;
    final label = err != null && err.isNotEmpty
        ? err
        : running
            ? loc.local_store_host_running(clients)
            : loc.local_store_host_stopped;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            running ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            color: color,
          ),
          const Gap(12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
