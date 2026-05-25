import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:voice_bill/services/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLogin = true;
  bool _sendingCode = false;
  String? _verificationId;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _smsController = TextEditingController();

  final _auth = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  Future<void> _handleEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_isLogin) {
        await _auth.signInWithEmail(email: email, password: password);
      } else {
        final exists = await _auth.emailExists(email);
        if (exists) {
          _showError('Email đã đăng ký, hãy đăng nhập');
          setState(() => _isLogin = true);
          return;
        }
        await _auth.signUpWithEmail(email: email, password: password);
      }
    } catch (e) {
      _showAuthError(e);
    }
  }

  Future<void> _handleGoogle() async {
    try {
      await _auth.signInWithGoogle();
    } catch (e) {
      _showAuthError(e);
    }
  }

  Future<void> _handlePhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('Vui lòng nhập số điện thoại');
      return;
    }

    setState(() => _sendingCode = true);
    await _auth.signInWithPhone(
      phoneNumber: phone,
      onCodeSent: (verificationId) {
        setState(() {
          _verificationId = verificationId;
          _sendingCode = false;
        });
      },
      onFailed: (error) {
        _showError(error.message ?? 'Gửi mã thất bại');
        setState(() => _sendingCode = false);
      },
    );
  }

  Future<void> _confirmSms() async {
    final code = _smsController.text.trim();
    if (code.isEmpty || _verificationId == null) {
      _showError('Vui lòng nhập mã xác nhận');
      return;
    }

    try {
      await _auth.confirmSmsCode(
        verificationId: _verificationId!,
        smsCode: code,
      );
    } catch (e) {
      _showAuthError(e);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          _showError('Email đã đăng ký, hãy đăng nhập');
          setState(() => _isLogin = true);
          return;
        case 'user-not-found':
          _showError('Email chưa đăng ký, vui lòng đăng ký trước');
          setState(() => _isLogin = false);
          return;
        case 'wrong-password':
          _showError('Mật khẩu không đúng');
          return;
        case 'invalid-email':
          _showError('Email không hợp lệ');
          return;
        case 'too-many-requests':
          _showError('Thử lại sau ít phút');
          return;
        case 'account-exists-with-different-credential':
          _showError('Email này đăng ký bằng phương thức khác');
          return;
        case 'invalid-credential':
          _showError('Thông tin đăng nhập không hợp lệ');
          return;
        default:
          _showError(error.message ?? 'Đăng nhập thất bại');
          return;
      }
    }

    _showError('Đăng nhập thất bại');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'VoiceBill',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin ? 'Đăng nhập để tiếp tục' : 'Tạo tài khoản mới',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nhập email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.trim().length < 6) {
                          return 'Mật khẩu tối thiểu 6 ký tự';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(_isLogin ? 'Đăng nhập' : 'Đăng ký'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin
                            ? 'Chưa có tài khoản? Đăng ký'
                            : 'Đã có tài khoản? Đăng nhập',
                      ),
                    ),
                    const Divider(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _handleGoogle,
                        icon: const Icon(Icons.g_mobiledata),
                        label: const Text('Tiếp tục với Google'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại (+84...)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _sendingCode ? null : _handlePhone,
                            child: Text(
                              _sendingCode ? 'Đang gửi mã...' : 'Gửi mã OTP',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _verificationId == null
                                ? null
                                : _confirmSms,
                            child: const Text('Xác nhận OTP'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _smsController,
                      decoration: const InputDecoration(
                        labelText: 'Mã OTP',
                        border: OutlineInputBorder(),
                      ),
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
