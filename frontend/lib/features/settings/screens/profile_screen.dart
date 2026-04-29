import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/profile_photo_crop_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _email;
  late TextEditingController _phone;
  late TextEditingController _members;
  late TextEditingController _bio;
  late TextEditingController _emergencyName;
  late TextEditingController _emergencyPhone;

  DateTime? _dob;
  Uint8List? _newPhotoBytes;
  String _newPhotoFilename = 'profile.jpg';
  bool _clearPhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).user;
    _name = TextEditingController(text: u?.name ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _members = TextEditingController(
      text: u?.householdMemberCount != null ? '${u!.householdMemberCount}' : '',
    );
    _bio = TextEditingController(text: u?.bio ?? '');
    _emergencyName = TextEditingController(text: u?.emergencyContactName ?? '');
    _emergencyPhone = TextEditingController(text: u?.emergencyContactPhone ?? '');
    _dob = u?.dateOfBirth;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _members.dispose();
    _bio.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final x = await ImagePicker().pickImage(
      source: source,
      imageQuality: 65,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (x == null || !mounted) return;
    final raw = await x.readAsBytes();
    if (!mounted) return;
    final cropped = await showProfilePhotoCrop(context, raw);
    if (!mounted || cropped == null) return;
    setState(() {
      _newPhotoBytes = cropped;
      _newPhotoFilename = 'profile.jpg';
      _clearPhoto = false;
    });
  }

  String? _dobLabel() {
    if (_dob == null) return null;
    return DateFormat.yMMMd().format(_dob!);
  }

  Future<void> _selectDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 30);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final dio = ref.read(authProvider.notifier).client.dio;
    final dobStr = _dob != null
        ? '${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
        : '';

    try {
      if (_newPhotoBytes != null) {
        final form = FormData.fromMap({
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'dateOfBirth': dobStr,
          'householdMemberCount': _members.text.trim(),
          'bio': _bio.text.trim(),
          'emergencyContactName': _emergencyName.text.trim(),
          'emergencyContactPhone': _emergencyPhone.text.trim(),
          'profilePhoto': MultipartFile.fromBytes(
            _newPhotoBytes!,
            filename: _newPhotoFilename,
          ),
        });
        await dio.patch('users/me', data: form);
      } else {
        await dio.patch(
          'users/me',
          data: {
            'name': _name.text.trim(),
            'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
            'phone': _phone.text.trim(),
            'dateOfBirth': _dob == null ? null : dobStr,
            'householdMemberCount': _members.text.trim().isEmpty
                ? null
                : int.tryParse(_members.text.trim()),
            'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
            'emergencyContactName':
                _emergencyName.text.trim().isEmpty ? null : _emergencyName.text.trim(),
            'emergencyContactPhone':
                _emergencyPhone.text.trim().isEmpty ? null : _emergencyPhone.text.trim(),
            if (_clearPhoto) 'clearProfilePhoto': true,
          },
        );
      }

      await ref.read(authProvider.notifier).refreshProfileFromServer();
      if (!mounted) return;
      setState(() {
        _newPhotoBytes = null;
        _clearPhoto = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = e.response?.data is Map && (e.response!.data['message'] is String)
          ? e.response!.data['message'] as String
          : 'Could not save profile';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save profile'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final basePhotoUrl = AppConstants.uploadUrlFromPath(user?.profilePhotoUrl);
    final photoUrl = basePhotoUrl != null ? '$basePhotoUrl?v=${authState.avatarRevision}' : null;
    final completeness = user?.profileCompletenessPercent ?? 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My profile'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile strength', style: AppTextStyles.labelMedium),
                    const SizedBox(height: AppDimensions.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: completeness / 100,
                        minHeight: 8,
                        backgroundColor: AppColors.border,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      '$completeness% complete — add a photo, date of birth, and household details so staff can recognise you faster.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: AppColors.primarySurface,
                      backgroundImage: _newPhotoBytes != null
                          ? MemoryImage(_newPhotoBytes!)
                          : (!_clearPhoto && photoUrl != null)
                              ? NetworkImage(photoUrl) as ImageProvider
                              : null,
                      child: (_clearPhoto || photoUrl == null) && _newPhotoBytes == null
                          ? Text(
                              _name.text.isNotEmpty ? _name.text[0].toUpperCase() : '?',
                              style: AppTextStyles.h1.copyWith(color: AppColors.primary),
                            )
                          : null,
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.photo_camera_outlined),
                                    title: const Text('Take photo'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _pickImage(ImageSource.camera);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library_outlined),
                                    title: const Text('Choose from gallery'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _pickImage(ImageSource.gallery);
                                    },
                                  ),
                                  if (user?.profilePhotoUrl != null || _newPhotoBytes != null)
                                    ListTile(
                                      leading: Icon(Icons.hide_image_outlined,
                                          color: AppColors.danger),
                                      title: Text('Remove photo',
                                          style: TextStyle(color: AppColors.danger)),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        setState(() {
                                          _newPhotoBytes = null;
                                          _clearPhoto = true;
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.xl),
              AppTextField(
                controller: _name,
                label: 'Full name',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: AppDimensions.md),
              AppTextField(
                controller: _email,
                label: 'Email (optional)',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppDimensions.md),
              AppTextField(
                controller: _phone,
                label: 'Phone',
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
              ),
              const SizedBox(height: AppDimensions.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date of birth', style: AppTextStyles.bodyMedium),
                subtitle: Text(
                  _dobLabel() ?? 'Not set — helps verify identity at the gate',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                ),
                trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                onTap: _selectDob,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  side: BorderSide(color: AppColors.border),
                ),
              ),
              if (_dob != null) ...[
                const SizedBox(height: AppDimensions.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _dob = null),
                    child: const Text('Clear date of birth'),
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.md),
              AppTextField(
                controller: _members,
                label: 'People in your home',
                keyboardType: TextInputType.number,
                hint: 'Including you — useful for security & amenities',
              ),
              const SizedBox(height: AppDimensions.md),
              AppTextField(
                controller: _bio,
                label: 'Short bio (optional)',
                maxLines: 3,
                hint: 'e.g. working professional, pet at home, accessibility needs',
              ),
              const SizedBox(height: AppDimensions.md),
              Text('Emergency contact', style: AppTextStyles.labelMedium),
              const SizedBox(height: AppDimensions.sm),
              AppTextField(
                controller: _emergencyName,
                label: 'Contact name',
              ),
              const SizedBox(height: AppDimensions.md),
              AppTextField(
                controller: _emergencyPhone,
                label: 'Contact phone',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppDimensions.xl),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
