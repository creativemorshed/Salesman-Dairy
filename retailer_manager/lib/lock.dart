import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'db.dart';
import 'utils.dart';

// =====================================================================
// পিন ও ফিঙ্গারপ্রিন্টের লজিক
// =====================================================================
class AppLock {
  AppLock._();
  static final AppLock instance = AppLock._();

  final AppDb _db = AppDb.instance;
  final Random _rng = Random.secure();

  String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<bool> hasPin() async => (await _db.getSetting('pin_hash')) != null;

  Future<void> setPin(String pin) async {
    final salt = List.generate(16, (_) => _rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await _db.setSetting('pin_salt', salt);
    await _db.setSetting('pin_hash', _hash(salt, pin));
  }

  Future<bool> verify(String pin) async {
    final hash = await _db.getSetting('pin_hash');
    final salt = await _db.getSetting('pin_salt');
    if (hash == null || salt == null) return true;
    return _hash(salt, pin) == hash;
  }

  Future<void> clearPin() async {
    await _db.deleteSetting('pin_hash');
    await _db.deleteSetting('pin_salt');
    await _db.deleteSetting('bio_enabled');
  }

  Future<bool> biometricEnabled() async =>
      (await _db.getSetting('bio_enabled')) == '1';

  Future<void> setBiometric(bool on) =>
      _db.setSetting('bio_enabled', on ? '1' : '0');

  /// ফিঙ্গারপ্রিন্ট/ফেস লক। কোনো সমস্যা হলে false দেয়, তখন পিন ব্যবহার হবে।
  Future<bool> authenticateBiometric() async {
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return false;
      return await auth.authenticate(
        localizedReason: 'ডায়েরি খুলতে ফিঙ্গারপ্রিন্ট দিন',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

// =====================================================================
// পিন প্যাড
// =====================================================================
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onComplete,
    this.error,
    this.extra,
    this.length = 4,
  });

  final String title;
  final String? error;
  final Widget? extra; // নিচের বাঁ কোণের বাটন (যেমন ফিঙ্গারপ্রিন্ট)
  final int length;
  final ValueChanged<String> onComplete;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';

  void _add(String d) {
    if (_pin.length >= widget.length) return;
    setState(() => _pin += d);
    if (_pin.length == widget.length) {
      final done = _pin;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _pin = '');
        widget.onComplete(done);
      });
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _key(Widget child, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 72,
          height: 60,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      );

  Widget _digit(String d) => _key(
      Text(bn(d), style: Theme.of(context).textTheme.headlineSmall),
      () => _add(d));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.length; i++)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? cs.primary : null,
                  border: Border.all(color: cs.primary, width: 1.5),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 36,
          child: Center(
            child: Text(widget.error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.error)),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final d in row) _digit(d)],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.extra == null
                ? const SizedBox(width: 84, height: 72)
                : _key(widget.extra!, null),
            _digit('0'),
            _key(const Icon(Icons.backspace_outlined), _back),
          ],
        ),
      ],
    );
  }
}

// =====================================================================
// পুরো অ্যাপের উপরে লক স্ক্রিন বসায় (MaterialApp.builder থেকে ব্যবহৃত)
// =====================================================================
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  /// এত সময়ের বেশি ব্যাকগ্রাউন্ডে থাকলে আবার লক হবে
  /// (কল/WhatsApp করে ফিরলে বারবার পিন চাইবে না)
  static const _grace = Duration(seconds: 60);

  bool _ready = false;
  bool _locked = false;
  bool _bio = false;
  bool _authing = false;
  String? _err;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _init() async {
    final has = await AppLock.instance.hasPin();
    final bio = has && await AppLock.instance.biometricEnabled();
    if (!mounted) return;
    setState(() {
      _ready = true;
      _locked = has;
      _bio = bio;
    });
    if (has && bio) _bioAuth();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (!_locked && !_authing) _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }

  Future<void> _onResume() async {
    final t = _pausedAt;
    _pausedAt = null;
    if (t == null || _locked) return;
    if (DateTime.now().difference(t) < _grace) return;
    final has = await AppLock.instance.hasPin();
    if (!has || !mounted) return;
    final bio = await AppLock.instance.biometricEnabled();
    if (!mounted) return;
    setState(() {
      _locked = true;
      _bio = bio;
      _err = null;
    });
    if (bio) _bioAuth();
  }

  Future<void> _bioAuth() async {
    if (_authing) return;
    _authing = true;
    final ok = await AppLock.instance.authenticateBiometric();
    _authing = false;
    if (ok && mounted) {
      setState(() {
        _locked = false;
        _err = null;
      });
    }
  }

  Future<void> _onPin(String pin) async {
    final ok = await AppLock.instance.verify(pin);
    if (!mounted) return;
    setState(() {
      if (ok) {
        _locked = false;
        _err = null;
      } else {
        _err = 'ভুল পিন, আবার চেষ্টা করুন';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Scaffold(
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, size: 48),
                        const SizedBox(height: 12),
                        PinPad(
                          title: 'পিন দিন',
                          error: _err,
                          onComplete: _onPin,
                          extra: _bio
                              ? IconButton(
                                  tooltip: 'ফিঙ্গারপ্রিন্ট',
                                  icon: const Icon(Icons.fingerprint, size: 30),
                                  onPressed: _bioAuth,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =====================================================================
// সেটিংস থেকে ব্যবহৃত: নতুন পিন সেট / পুরনো পিন যাচাই
// =====================================================================
Future<bool> setupPin(BuildContext context) async {
  final r = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const _PinSetupScreen()),
  );
  return r ?? false;
}

Future<bool> verifyPin(BuildContext context,
    {String title = 'বর্তমান পিন দিন'}) async {
  final r = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => _PinVerifyScreen(title: title)),
  );
  return r ?? false;
}

class _PinSetupScreen extends StatefulWidget {
  const _PinSetupScreen();

  @override
  State<_PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<_PinSetupScreen> {
  String? _first;
  String? _err;

  Future<void> _onPin(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _err = null;
      });
    } else if (_first == pin) {
      await AppLock.instance.setPin(pin);
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        _first = null;
        _err = 'দুটো পিন মেলেনি, আবার শুরু করুন';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('অ্যাপ লক')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PinPad(
                  title: _first == null
                      ? 'নতুন ৪ সংখ্যার পিন দিন'
                      : 'আবার একই পিন দিন',
                  error: _err,
                  onComplete: _onPin,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Text(
                    'পিন ভুলে গেলে অ্যাপ খুলতে পারবেন না। তাই নিয়মিত ব্যাকআপ নিয়ে রাখুন।',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinVerifyScreen extends StatefulWidget {
  const _PinVerifyScreen({required this.title});
  final String title;

  @override
  State<_PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<_PinVerifyScreen> {
  String? _err;

  Future<void> _onPin(String pin) async {
    final ok = await AppLock.instance.verify(pin);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _err = 'ভুল পিন');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('অ্যাপ লক')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: PinPad(title: widget.title, error: _err, onComplete: _onPin),
          ),
        ),
      ),
    );
  }
}
