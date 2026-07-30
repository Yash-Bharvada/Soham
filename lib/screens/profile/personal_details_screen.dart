import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tenant_card.dart';

class PersonalDetailsScreen extends ConsumerStatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  ConsumerState<PersonalDetailsScreen> createState() =>
      _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState
    extends ConsumerState<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController(text: '8160695640');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _populate(profile) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = profile?.name ?? '';
    _emailCtrl.text = profile?.email ?? 'chetnabharvada1234@gmail.com';
    _phoneCtrl.text = (profile?.phone != null && profile!.phone!.isNotEmpty)
        ? profile.phone!
        : '8160695640';
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.navy),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.navy),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (result == null) return;
    final picked = await picker.pickImage(
      source: result,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final bytes = await picked.readAsBytes();
      final path = '${user.id}/avatar.jpg';

      await Supabase.instance.client.storage
          .from('documents')
          .uploadBinary(path, bytes,
              fileOptions:
                  const FileOptions(upsert: true, contentType: 'image/jpeg'));

      final signedUrl = await Supabase.instance.client.storage
          .from('documents')
          .createSignedUrl(path, 864000);

      await Supabase.instance.client.from('profiles').update({
        'avatar_url': signedUrl,
      }).eq('id', user.id);

      ref.invalidate(currentProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Photo upload failed: $e'),
              backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('profiles').update({
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
        }).eq('id', user.id);

        ref.invalidate(currentProfileProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    profileAsync.whenData((profile) => _populate(profile));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Navy Header ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: AppDimensions.screenPadding,
                right: AppDimensions.screenPadding,
                bottom: 24,
              ),
              decoration: AppDecorations.navyGradient,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Personal details',
                            style: AppTextStyles.headerTitle),
                        Text('Manage your personal contact & profile photo',
                            style: AppTextStyles.headerSubtitle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Interactive Avatar Upload ─────────────────────────
                Center(
                  child: Stack(
                    children: [
                      profileAsync.when(
                        data: (p) => InitialsAvatar(
                          name: p?.name ?? 'User',
                          avatarUrl: p?.avatarUrl,
                          size: 84,
                        ),
                        loading: () => const CircleAvatar(radius: 42),
                        error: (_, __) => const CircleAvatar(radius: 42),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _uploadingPhoto ? null : _uploadAvatar,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: AppColors.coral,
                              shape: BoxShape.circle,
                            ),
                            child: _uploadingPhoto
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt,
                                    color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _uploadingPhoto ? null : _uploadAvatar,
                    child: Text(
                      _uploadingPhoto
                          ? 'Uploading photo...'
                          : 'Change profile photo',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.lightBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppDecorations.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('Full name'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration:
                              const InputDecoration(hintText: 'Your full name'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter your name'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        _Label('Email address'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailCtrl,
                          enabled: false,
                          decoration: InputDecoration(
                            hintText: 'chetnabharvada1234@gmail.com',
                            fillColor: AppColors.background,
                            suffixIcon: const Icon(Icons.lock_outline,
                                size: 18, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _Label('Phone number'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: '8160695640',
                            prefixIcon: Icon(Icons.phone_outlined,
                                size: 18, color: AppColors.navy),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter phone number'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        _Label('Property'),
                        const SizedBox(height: 6),
                        TextFormField(
                          initialValue: 'Soham PG',
                          enabled: false,
                          decoration: InputDecoration(
                            fillColor: AppColors.background,
                            prefixIcon: const Icon(Icons.home_outlined,
                                size: 18, color: AppColors.navy),
                          ),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text('Save changes',
                                    style: AppTextStyles.labelLarge),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      );
}
