import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:voice_bill/services/auth_service.dart';
import 'package:voice_bill/services/bill_service.dart';
import 'package:voice_bill/services/profile_service.dart';
import 'package:voice_bill/services/product_service.dart';

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
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
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
        bankName: _selectedBank?.name,
        bankShortName: _selectedBank?.shortName,
        bankBin: _selectedBank?.bin,
        accountNumber: _accountNumberController.text.trim(),
        accountName: _accountNameController.text.trim(),
        qrMode: _useQrImage ? 'image' : 'auto',
      );
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
      backgroundColor: Colors.white,
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
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _saveProfile,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text('Lưu'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<UserProfile>(
          stream: _profileService.streamProfile(),
          builder: (context, snapshot) {
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

            if (!_initialized && snapshot.hasData) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _displayNameController.text = profile.displayName;
                _storeController.text = profile.storeName;
                _phoneController.text = profile.phone;
                _addressController.text = profile.address;
                _accountNameController.text = profile.accountName;
                _accountNumberController.text = profile.accountNumber;
                _useQrImage = profile.qrMode == 'image';
                if (_selectedBank == null && profile.bankBin.isNotEmpty) {
                  _selectedBank = _banks.firstWhere(
                    (bank) => bank.bin == profile.bankBin,
                    orElse: () => _banks.first,
                  );
                }
                if (mounted) {
                  setState(() => _initialized = true);
                }
              });
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEFEFEF)),
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
                              backgroundColor: Colors.black87,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
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
                            color: const Color(0xFFFFE6D9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Color(0xFFB86B45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'THÔNG TIN CÁ NHÂN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 12),
                _InputField(
                  controller: _displayNameController,
                  label: 'Tên người dùng',
                  icon: Icons.person,
                ),
                const SizedBox(height: 16),
                const Text(
                  'THÔNG TIN CỬA HÀNG',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
                  ),
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
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFEFEFEF)),
                const SizedBox(height: 8),
                const Text(
                  'THANH TOÁN & MÃ QR',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEFEFEF)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.account_balance),
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
                      const SizedBox(height: 10),
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
                                foregroundColor: Colors.black87,
                                side: const BorderSide(
                                  color: Color(0xFFE5E5E5),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Color(0xFFE5E5E5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _migrating ? null : _runMigration,
                  icon: _migrating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_alt),
                  label: const Text('Cập nhật dữ liệu (1 lần)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Color(0xFFE5E5E5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.black87),
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
