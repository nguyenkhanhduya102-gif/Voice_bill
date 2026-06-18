import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:voice_bill/pages/onboarding_page.dart';
import 'package:voice_bill/pages/tax_page.dart';
import 'package:voice_bill/services/auth_service.dart';
import 'package:voice_bill/services/bill_service.dart';
import 'package:voice_bill/services/profile_service.dart';
import 'package:voice_bill/services/product_service.dart';
import 'package:voice_bill/utils/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final ProductService _productService = ProductService();
  final BillService _billService = BillService();
  final ImagePicker _imagePicker = ImagePicker();
  

  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _taxCodeController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _accountNumberController =TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  bool _useQrImage = false;
  bool _uploadingAvatar = false;
  bool _uploadingQr = false;
  bool _migrating = false;
  int _avatarRefreshKey = 0;
  _BankOption? _selectedBank;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _signOut() async {
    await _authService.signOut();
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await _profileService.updateProfile(
        displayName: _displayNameController.text.trim(),
        storeName: _storeController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        taxCode: _taxCodeController.text.trim(),
        bankName: _selectedBank?.name,
        bankShortName: _selectedBank?.shortName,
        bankBin: _selectedBank?.bin,
        accountNumber: _accountNumberController.text.trim(),
        accountName: _accountNameController.text.trim(),
        qrMode: _useQrImage ? 'image' : 'auto',
      );
      HapticFeedback.mediumImpact();
      _showSnack('Đã lưu thông tin');
    } catch (_) {
      _showSnack('Không thể lưu thông tin');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickAvatar(UserProfile profile) async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) {
      return;
    }

    try {
      setState(() => _uploadingAvatar = true);
      final url = await _profileService
          .uploadAvatar(file)
          .timeout(const Duration(seconds: 20));
      await _profileService
          .updateProfile(
            displayName: _displayNameController.text.trim(),
            storeName: _storeController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            photoUrl: url,
          )
          .timeout(const Duration(seconds: 20));
      if (mounted) {
        setState(
          () => _avatarRefreshKey = DateTime.now().millisecondsSinceEpoch,
        );
      }
      _showSnack('Đã cập nhật ảnh đại diện');
    } on TimeoutException {
      _showSnack('Tải ảnh quá lâu, vui lòng thử lại');
    } catch (e) {
      _showSnack('Không thể tải ảnh');
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<void> _pickQrImage(UserProfile profile) async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) {
      return;
    }

    try {
      setState(() => _uploadingQr = true);
      final url = await _profileService
          .uploadQrImage(file)
          .timeout(const Duration(seconds: 20));
      await _profileService
          .updateProfile(
            displayName: _displayNameController.text.trim(),
            storeName: _storeController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            bankName: _selectedBank?.name,
            bankShortName: _selectedBank?.shortName,
            bankBin: _selectedBank?.bin,
            accountNumber: _accountNumberController.text.trim(),
            accountName: _accountNameController.text.trim(),
            qrImageUrl: url,
            qrMode: 'image',
          )
          .timeout(const Duration(seconds: 20));
      if (mounted) {
        setState(() => _useQrImage = true);
      }
      _showSnack('Đã cập nhật ảnh QR');
    } on TimeoutException {
      _showSnack('Tải ảnh QR quá lâu, vui lòng thử lại');
    } catch (e) {
      _showSnack('Không thể tải ảnh QR');
    } finally {
      if (mounted) {
        setState(() => _uploadingQr = false);
      }
    }
  }

  Future<void> _pickBank() async {
    final bank = await showModalBottomSheet<_BankOption>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: _banks.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = _banks[index];
            return ListTile(
              title: Text(item.name),
              subtitle: Text('${item.shortName} • ${item.bin}'),
              onTap: () => Navigator.of(context).pop(item),
            );
          },
        );
      },
    );

    if (bank != null) {
      setState(() => _selectedBank = bank);
    }
  }

  Future<void> _runMigration() async {
    if (_migrating) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cập nhật dữ liệu'),
          content: const Text(
            'Thao tác này sẽ cập nhật giá số cho sản phẩm và hóa đơn. '
            'Chỉ cần chạy 1 lần.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Chạy'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      setState(() => _migrating = true);
      final productUpdated = await _productService.backfillPriceValues();
      final billUpdated = await _billService.backfillBillItemPrices();
      _showSnack('Đã cập nhật $productUpdated sản phẩm, $billUpdated hóa đơn');
    } catch (_) {
      _showSnack('Không thể cập nhật dữ liệu');
    } finally {
      if (mounted) {
        setState(() => _migrating = false);
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _storeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxCodeController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  /// Thẻ nhóm cài đặt: tiêu đề + icon + nội dung.
  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: context.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  /// Nút lưu to, rõ — đặt ngay trong thẻ để người lớn tuổi thấy.
  Widget _saveButton(String label) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _saveProfile,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check),
        label: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        surfaceTintColor: context.surface,
        foregroundColor: context.textPrimary,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Cài đặt',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<UserProfile>(
          stream: _profileService.streamProfile(),
          builder: (context, snapshot) {
            // Chờ tải lần đầu -> hiện loader, tránh việc đổ dữ liệu muộn ghi đè
            // lên chữ người dùng vừa gõ (bug lưu không ăn).
            if (!_initialized &&
                snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final profile =
                snapshot.data ??
                const UserProfile(
                  displayName: '',
                  storeName: '',
                  phone: '',
                  address: '',
                  photoUrl: '',
                  bankName: '',
                  bankShortName: '',
                  bankBin: '',
                  accountNumber: '',
                  accountName: '',
                  qrImageUrl: '',
                  qrMode: 'auto',
                );

            // Đổ dữ liệu vào ô đúng MỘT lần khi doc đã tải xong.
            if (!_initialized) {
              _displayNameController.text = profile.displayName;
              _storeController.text = profile.storeName;
              _phoneController.text = profile.phone;
              _addressController.text = profile.address;
              _taxCodeController.text = profile.taxCode;
              _accountNameController.text = profile.accountName;
              _accountNumberController.text = profile.accountNumber;
              _useQrImage = profile.qrMode == 'image';
              if (_selectedBank == null && profile.bankBin.isNotEmpty) {
                _selectedBank = _banks.firstWhere(
                  (bank) => bank.bin == profile.bankBin,
                  orElse: () => _banks.first,
                );
              }
              _initialized = true;
            }

            final avatarText =
                (profile.displayName.isNotEmpty
                        ? profile.displayName
                        : profile.storeName)
                    .trim();
            final initials = avatarText.isEmpty
                ? 'VB'
                : avatarText
                      .split(' ')
                      .where((part) => part.isNotEmpty)
                      .take(2)
                      .map((part) => part[0].toUpperCase())
                      .join();

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.border),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                              CircleAvatar(
                              radius: 32,
                              backgroundColor: context.brand,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            if (profile.photoUrl.isNotEmpty)
                              ClipOval(
                                child: Image.network(
                                  profile.photoUrl,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  key: ValueKey(_avatarRefreshKey),
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            if (_uploadingAvatar)
                              const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          profile.storeName.isNotEmpty
                              ? profile.storeName
                              : 'Cập nhật thông tin cửa hàng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _uploadingAvatar
                            ? null 
                            : () => _pickAvatar(profile),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: context.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.edit,
                            size: 16,
                            color: context.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  title: 'Thông tin cửa hàng',
                  icon: Icons.storefront,
                  children: [
                    _InputField(
                      controller: _displayNameController,
                      label: 'Tên của bạn',
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      controller: _storeController,
                      label: 'Tên cửa hàng',
                      icon: Icons.storefront,
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      controller: _phoneController,
                      label: 'Số điện thoại',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      controller: _addressController,
                      label: 'Địa chỉ',
                      icon: Icons.location_on,
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      controller: _taxCodeController,
                      label: 'Mã số thuế (nếu có)',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _saveButton('Lưu thông tin'),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.border),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.account_balance_wallet_outlined,
                        color: context.brand),
                    title: const Text('Thuế & Báo cáo'),
                    subtitle: const Text(
                        'Doanh thu năm, cảnh báo ngưỡng, sổ S1a'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TaxPage()),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  title: 'Thanh toán (QR chuyển khoản)',
                  icon: Icons.account_balance,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          Icon(Icons.account_balance, color: context.brand),
                      title: const Text('Ngân hàng'),
                      subtitle: Text(
                        _selectedBank?.name ??
                            (profile.bankName.isNotEmpty
                                ? profile.bankName
                                : 'Chọn ngân hàng'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickBank,
                    ),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _accountNumberController,
                      label: 'Số tài khoản',
                      icon: Icons.account_balance_wallet,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      controller: _accountNameController,
                      label: 'Chủ tài khoản',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dùng ảnh QR tải lên'),
                      value: _useQrImage,
                      onChanged: (value) {
                        setState(() => _useQrImage = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _uploadingQr
                                ? null
                                : () => _pickQrImage(profile),
                            icon: _uploadingQr
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.upload),
                            label: const Text('Tải ảnh QR'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.brand,
                              side: BorderSide(color: context.brand),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        if (profile.qrImageUrl.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              profile.qrImageUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _saveButton('Lưu thanh toán'),
                  ],
                ),
                _card(
                  title: 'Cài đặt ứng dụng',
                  icon: Icons.tune,
                  children: [
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeController,
                      builder: (context, mode, _) {
                        final isDarkNow =
                            Theme.of(context).brightness == Brightness.dark;
                        return SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: isDarkNow,
                          onChanged: (_) => themeController.toggle(
                            Theme.of(context).brightness,
                          ),
                          secondary: Icon(
                            isDarkNow ? Icons.dark_mode : Icons.light_mode,
                            color: context.brand,
                          ),
                          title: const Text('Chế độ tối'),
                          subtitle: Text(
                            mode == ThemeMode.system
                                ? 'Đang theo hệ thống'
                                : (isDarkNow ? 'Đang bật' : 'Đang tắt'),
                          ),
                        );
                      },
                    ),
                    Divider(color: context.border, height: 1),
                    ValueListenableBuilder<double>(
                      valueListenable: textScaleController,
                      builder: (context, scale, _) {
                        final isLarge = scale >= TextScaleController.large;
                        return SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: isLarge,
                          onChanged: (v) => textScaleController.setLarge(v),
                          secondary:
                              Icon(Icons.format_size, color: context.brand),
                          title: const Text('Chữ lớn'),
                          subtitle: Text(
                            isLarge ? 'Đang bật' : 'Phóng to chữ cho dễ đọc',
                          ),
                        );
                      },
                    ),
                    Divider(color: context.border, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          Icon(Icons.help_outline, color: context.brand),
                      title: const Text('Xem lại hướng dẫn'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const OnboardingPage(isFirstRun: false),
                        ),
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: _migrating ? null : _runMigration,
                    icon: _migrating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.sync_alt,
                            size: 18, color: context.textMuted),
                    label: Text(
                      'Cập nhật dữ liệu (1 lần)',
                      style: TextStyle(color: context.textMuted),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: context.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.brand),
        ),
      ),
    );
  }
}

class _BankOption {
  final String name;
  final String shortName;
  final String bin;

  const _BankOption({
    required this.name,
    required this.shortName,
    required this.bin,
  });
}

const List<_BankOption> _banks = [
  _BankOption(name: 'Vietcombank', shortName: 'VCB', bin: '970436'),
  _BankOption(name: 'VietinBank', shortName: 'VTB', bin: '970415'),
  _BankOption(name: 'BIDV', shortName: 'BIDV', bin: '970418'),
  _BankOption(name: 'ACB', shortName: 'ACB', bin: '970416'),
  _BankOption(name: 'Techcombank', shortName: 'TCB', bin: '970407'),
  _BankOption(name: 'MB Bank', shortName: 'MB', bin: '970422'),
  _BankOption(name: 'VPBank', shortName: 'VPB', bin: '970432'),
  _BankOption(name: 'Sacombank', shortName: 'STB', bin: '970403'),
  _BankOption(name: 'SHB', shortName: 'SHB', bin: '970443'),
  _BankOption(name: 'TPBank', shortName: 'TPB', bin: '970423'),

];
