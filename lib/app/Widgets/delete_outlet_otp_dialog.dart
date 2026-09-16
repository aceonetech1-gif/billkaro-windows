import 'package:billkaro/config/config.dart';
import 'package:dio/dio.dart';

/// Owner picks email or phone, receives an OTP, then confirms outlet deletion.
/// Returns `true` only after the outlet is deleted on the server.
Future<bool> showDeleteOutletOtpDialog({
  required String outletName,
  required String ownerId,
  required String outletId,
  String? ownerEmail,
  String? ownerPhone,
}) async {
  return await showGeneralDialog<bool>(
        context: Get.context!,
        barrierDismissible: false,
        barrierLabel: 'Dismiss',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 250),
        transitionBuilder: (_, anim, __, child) {
          return ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          );
        },
        pageBuilder: (ctx, _, __) => _DeleteOutletOtpDialog(
          outletName: outletName,
          ownerId: ownerId,
          outletId: outletId,
          ownerEmail: ownerEmail,
          ownerPhone: ownerPhone,
        ),
      ) ??
      false;
}

class _DeleteOutletOtpDialog extends StatefulWidget {
  final String outletName;
  final String ownerId;
  final String outletId;
  final String? ownerEmail;
  final String? ownerPhone;

  const _DeleteOutletOtpDialog({
    required this.outletName,
    required this.ownerId,
    required this.outletId,
    this.ownerEmail,
    this.ownerPhone,
  });

  @override
  State<_DeleteOutletOtpDialog> createState() => _DeleteOutletOtpDialogState();
}

class _DeleteOutletOtpDialogState extends State<_DeleteOutletOtpDialog> {
  final _otpController = TextEditingController();
  String _channel = 'email';
  bool _otpSent = false;
  bool _sending = false;
  bool _deleting = false;
  String? _destination;
  String? _error;
  int _resendIn = 0;
  int _resendToken = 0;

  bool get _hasEmail => (widget.ownerEmail ?? '').trim().isNotEmpty;
  bool get _hasPhone => (widget.ownerPhone ?? '').trim().isNotEmpty;
  bool get _busy => _sending || _deleting;

  @override
  void initState() {
    super.initState();
    if (_hasEmail) {
      _channel = 'email';
    } else if (_hasPhone) {
      _channel = 'phone';
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String _maskEmail(String email) {
    final parts = email.trim().split('@');
    if (parts.length != 2 || parts[0].isEmpty) return email;
    final visible = parts[0].length <= 2 ? parts[0] : parts[0].substring(0, 2);
    return '$visible****@${parts[1]}';
  }

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return phone;
    final last = digits.substring(digits.length - 4);
    final first = digits.length >= 6 ? digits.substring(0, 2) : '';
    return '$first****$last';
  }

  String get _previewDestination {
    if (_channel == 'email' && _hasEmail) return _maskEmail(widget.ownerEmail!);
    if (_channel == 'phone' && _hasPhone) return _maskPhone(widget.ownerPhone!);
    return '';
  }

  void _startResendCooldown() {
    final token = ++_resendToken;
    _resendIn = 30;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || token != _resendToken) return false;
      setState(() => _resendIn = (_resendIn - 1).clamp(0, 30));
      return _resendIn > 0;
    });
  }

  Future<void> _sendOtp() async {
    if (_busy) return;
    if (_channel == 'email' && !_hasEmail) {
      setState(() => _error = 'Owner email is not available.');
      return;
    }
    if (_channel == 'phone' && !_hasPhone) {
      setState(() => _error = 'Owner phone is not available.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    String? error;
    final res = await callApi(
      Get.find<ApiClient>().sendDeleteOutletOtp(
        widget.ownerId,
        widget.outletId,
        {'channel': _channel},
      ),
      showLoader: false,
      apiErrorHandler: (dioError) async {
        error = _messageFromDio(dioError);
        return true;
      },
    );

    if (!mounted) return;

    if (res is Map && res['status'] == 'success') {
      final dest = res['data'] is Map
          ? res['data']['destination']?.toString()
          : null;
      setState(() {
        _sending = false;
        _otpSent = true;
        _destination = (dest == null || dest.isEmpty)
            ? _previewDestination
            : dest;
      });
      _startResendCooldown();
      return;
    }

    setState(() {
      _sending = false;
      _error = error ??
          (res is Map ? res['message']?.toString() : null) ??
          'Failed to send OTP. Please try again.';
    });
  }

  Future<void> _confirmDelete() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP.');
      return;
    }

    setState(() {
      _deleting = true;
      _error = null;
    });

    String? error;
    final res = await callApi(
      Get.find<ApiClient>().deleteOutlet(
        widget.ownerId,
        widget.outletId,
        {'otp': otp},
      ),
      showLoader: false,
      apiErrorHandler: (dioError) async {
        error = _messageFromDio(dioError);
        return true;
      },
    );

    if (!mounted) return;

    if (res is Map && res['status'] == 'success') {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _deleting = false;
      _error = error ??
          (res is Map ? res['message']?.toString() : null) ??
          'Failed to delete outlet';
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = (width - 48).clamp(280.0, 420.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogWidth,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red.shade400,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Outlet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D23),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Permanently delete ${widget.outletName}. An OTP will be sent to the owner before this outlet can be removed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Send OTP to',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ChannelChip(
                      label: 'Email',
                      subtitle: _hasEmail
                          ? _maskEmail(widget.ownerEmail!)
                          : 'Not available',
                      selected: _channel == 'email',
                      enabled: _hasEmail && !_busy,
                      onTap: () => _selectChannel('email'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ChannelChip(
                      label: 'Phone',
                      subtitle: _hasPhone
                          ? _maskPhone(widget.ownerPhone!)
                          : 'Not available',
                      selected: _channel == 'phone',
                      enabled: _hasPhone && !_busy,
                      onTap: () => _selectChannel('phone'),
                    ),
                  ),
                ],
              ),
              if (!_hasEmail && !_hasPhone) ...[
                const SizedBox(height: 10),
                Text(
                  'Owner email and phone are missing. Add one before deleting this outlet.',
                  style: TextStyle(fontSize: 12.5, color: Colors.red.shade700),
                ),
              ],
              if (_otpSent) ...[
                const SizedBox(height: 16),
                Text(
                  _destination == null || _destination!.isEmpty
                      ? 'Enter the 6-digit OTP'
                      : 'OTP sent to $_destination',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _otpController,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '------',
                    filled: true,
                    fillColor: const Color(0xFFF7F7F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12.5, color: Colors.red.shade700),
                ),
              ],
              const SizedBox(height: 18),
              if (!_otpSent)
                ElevatedButton(
                  onPressed: (!_hasEmail && !_hasPhone) || _busy ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _sending ? 'Sending OTP...' : 'Send OTP',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              else ...[
                ElevatedButton(
                  onPressed: _busy ? null : _confirmDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade500,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _deleting ? 'Deleting...' : 'Verify OTP & Delete',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy || _resendIn > 0 ? null : _sendOtp,
                  child: Text(
                    _resendIn > 0 ? 'Resend OTP in ${_resendIn}s' : 'Resend OTP',
                  ),
                ),
              ],
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectChannel(String channel) {
    if (_channel == channel) return;
    setState(() {
      _channel = channel;
      _otpSent = false;
      _destination = null;
      _error = null;
      _resendToken++;
      _resendIn = 0;
      _otpController.clear();
    });
  }
}

class _ChannelChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ChannelChip({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppColor.primary : Colors.grey.shade300;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColor.primary.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _messageFromDio(DioException error) {
  final data = error.response?.data;
  if (data is Map) {
    final message = data['message'];
    if (message is List) return message.map((e) => e.toString()).join(', ');
    if (message != null) return message.toString();
  }
  if (data is String && data.trim().isNotEmpty) return data;
  return null;
}
