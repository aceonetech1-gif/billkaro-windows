import 'package:billkaro/app/services/local_store/local_store_client.dart';
import 'package:billkaro/app/services/local_store/local_store_host_service.dart';
import 'package:billkaro/app/services/local_store/local_store_protocol.dart';
import 'package:billkaro/app/services/local_store/local_store_session.dart';
import 'package:billkaro/app/services/local_store/local_store_staff_session.dart';
import 'package:billkaro/config/config.dart';

/// Join another BillKaro PC that is running as the store host (same Wi‑Fi).
Future<bool> showLocalStoreJoinDialog() async {
  final result = await Get.dialog<bool>(
    const _LocalStoreJoinDialog(),
    barrierDismissible: false,
  );
  return result == true;
}

class _LocalStoreJoinDialog extends StatefulWidget {
  const _LocalStoreJoinDialog();

  @override
  State<_LocalStoreJoinDialog> createState() => _LocalStoreJoinDialogState();
}

class _LocalStoreJoinDialogState extends State<_LocalStoreJoinDialog> {
  final _tokenCtrl = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final loc = AppLocalizations.of(context)!;
    final token = LocalStoreProtocol.normalizeJoinCode(_tokenCtrl.text);

    if (token.isEmpty) {
      setState(() => _error = loc.local_store_join_fields_required);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final client = LocalStoreClient();
    try {
      final result = await client.joinByCode(token);
      if (!result.ok) {
        setState(() {
          _busy = false;
          _error = result.error ?? loc.local_store_join_failed;
        });
        return;
      }

      final pref = Get.find<AppPref>();
      if (Get.isRegistered<LocalStoreHostService>()) {
        final host = Get.find<LocalStoreHostService>();
        if (host.isRunning.value || pref.localStoreHostEnabled) {
          await host.setEnabled(false);
        }
      } else {
        pref.localStoreHostEnabled = false;
      }

      pref.localStoreClientBaseUrl = result.baseUrl;
      pref.localStoreClientToken = result.token;
      pref.localStoreClientOutletName = result.outletName ?? '';

      await registerWithLocalStoreHost(
        pref: pref,
        baseUrl: result.baseUrl,
        token: result.token,
        joinMethod: 'code',
      );
      await startLocalStoreLiveIfJoined(pref);

      if (mounted) Get.back(result: true);
      showSuccess(
        description: loc.local_store_joined(
          result.outletName?.isNotEmpty == true
              ? result.outletName!
              : result.baseUrl,
        ),
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.pin_outlined, color: AppColor.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loc.local_store_join_title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => Get.back(result: false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Gap(6),
              Text(
                loc.local_store_join_subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const Gap(16),
              TextField(
                controller: _tokenCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: loc.local_store_join_code,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_busy) _join();
                },
              ),
              if (_error != null) ...[
                const Gap(10),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const Gap(16),
              FilledButton(
                onPressed: _busy ? null : _join,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(loc.local_store_join_action),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
