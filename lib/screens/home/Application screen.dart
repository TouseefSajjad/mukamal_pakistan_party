
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mukammalpakistanparty/%20config/app_theme.dart';


// ─────────────────────────────────────────────────────────────
//  LOCAL HELPERS  (only things AppTheme doesn't cover)
// ─────────────────────────────────────────────────────────────
class _C {
  static const border      = Color(0xFFE0E0E0);
  static const infoBg      = Color(0xFFE8F5E9); // soft green tint
  static const warningBg   = Color(0xFFFFFDE7);
  static const warningText = Color(0xFFF57F17);
}

// ─────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────
class _PersonalInfo {
  String fullName = '';
  String cnic     = '';
}

class _ContactInfo {
  String phone    = '';
  String district = '';
}

class _DocumentSet {
  File? profileImage;
}

// ─────────────────────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────────────────────
class MembershipApplicationScreen extends StatefulWidget {
  final String userId;
  const MembershipApplicationScreen({super.key, required this.userId});

  @override
  State<MembershipApplicationScreen> createState() =>
      _MembershipApplicationScreenState();
}

class _MembershipApplicationScreenState
    extends State<MembershipApplicationScreen> {
  int _currentStep = 0;
  static const int _totalSteps = 4;

  final _personalKey = GlobalKey<FormState>();
  final _contactKey  = GlobalKey<FormState>();

  final _personal = _PersonalInfo();
  final _contact  = _ContactInfo();
  final _docs     = _DocumentSet();

  final _fullNameC = TextEditingController();
  final _cnicC     = TextEditingController();
  final _phoneC    = TextEditingController();
  final _districtC = TextEditingController();

  bool   _isSubmitting   = false;
  double _uploadProgress = 0.0;
  String _uploadStatus   = '';
  bool   _submitted      = false;

  @override
  void dispose() {
    _fullNameC.dispose();
    _cnicC.dispose();
    _phoneC.dispose();
    _districtC.dispose();
    super.dispose();
  }

  // ── Navigation ───────────────────────────────────────────────
  void _goNext() {
    if (_currentStep == 0 && !_validatePersonal())  return;
    if (_currentStep == 1 && !_validateContact())   return;
    if (_currentStep == 2 && !_validateDocuments()) return;
    if (_currentStep < _totalSteps - 1) setState(() => _currentStep++);
  }

  void _goBack() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // ── Validation ───────────────────────────────────────────────
  bool _validatePersonal() => _personalKey.currentState?.validate() ?? false;
  bool _validateContact()  => _contactKey.currentState?.validate()  ?? false;
  bool _validateDocuments() {
    if (_docs.profileImage == null) { _snack('Profile image is required'); return false; }
    return true;
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: error ? AppTheme.criticalRed : AppTheme.primaryGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── File picker ──────────────────────────────────────────────
  Future<File?> _pickSingleImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    return p == null ? null : File(p.path);
  }

  // ── Upload ───────────────────────────────────────────────────
  Future<String> _uploadFile(File file, String path) async {
    final task = FirebaseStorage.instance.ref().child(path).putFile(file);
    task.snapshotEvents.listen((e) {
      if (e.totalBytes > 0) setState(() => _uploadProgress = e.bytesTransferred / e.totalBytes);
    });
    return (await task).ref.getDownloadURL();
  }

  // ── Submit ───────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_validateDocuments()) return;

    // Always use the live signed-in user's UID, not the value passed into
    // the widget. If these ever differ, Firestore/Storage security rules
    // that check `request.auth.uid` will correctly reject the write as
    // unauthorized.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _snack('You must be signed in to submit an application.');
      return;
    }
    if (currentUser.uid != widget.userId) {
      _snack('Session mismatch detected. Please sign in again and retry.');
      return;
    }

    setState(() { _isSubmitting = true; _uploadProgress = 0; });

    try {
      final uid = currentUser.uid;
      final ts  = DateTime.now().millisecondsSinceEpoch;

      // TEMP DEBUG — remove once the unauthorized error is fixed.
      debugPrint('DEBUG: submitting as uid=$uid, widget.userId=${widget.userId}');

      setState(() => _uploadStatus = 'Uploading profile image…');
      final String profileUrl;
      try {
        profileUrl = await _uploadFile(_docs.profileImage!, 'memberships/$uid/profile_$ts.jpg');
        debugPrint('DEBUG: Storage upload succeeded -> $profileUrl');
      } catch (e) {
        debugPrint('DEBUG: Storage upload FAILED -> $e');
        rethrow;
      }

      setState(() => _uploadStatus = 'Saving application…');
      await FirebaseFirestore.instance.collection('membership_applications').add({
        'user_id': uid,
        'name':    _personal.fullName,
        'cnic':    _personal.cnic,
        'phone':   _contact.phone,
        'district': _contact.district,
        'profile_picture': profileUrl,
        'status':       'pending',
        'submitted_at': FieldValue.serverTimestamp(),
        'reviewed_at':  null,
        'reviewed_by':  null,
      });

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profile_picture':    profileUrl,
        'membership_status': 'pending',
      });

      debugPrint('DEBUG: Firestore write succeeded');
      setState(() { _submitted = true; _isSubmitting = false; });
    } catch (e) {
      debugPrint('DEBUG: submission FAILED -> $e');
      setState(() => _isSubmitting = false);
      _snack('Submission failed: $e');
    }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_submitted) return _SuccessView(onDone: () => Navigator.pop(context));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(children: [
            _StepProgressBar(currentStep: _currentStep, totalSteps: _totalSteps),
            Expanded(child: _buildStep()),
            _buildNavBar(),
          ]),
          if (_isSubmitting)
            _UploadOverlay(progress: _uploadProgress, status: _uploadStatus),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    const titles = ['Personal Info', 'Contact Info', 'Document', 'Review & Submit'];
    return AppBar(
      backgroundColor: AppTheme.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: _currentStep > 0
          ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: _goBack)
          : IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titles[_currentStep],
              style: AppTheme.subHeading.copyWith(color: AppTheme.textOnPrimary, fontSize: 16)),
          Text('Step ${_currentStep + 1} of $_totalSteps',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textOnPrimary.withOpacity(0.8), fontSize: 12)),
        ],
      ),
      centerTitle: false,
    );
  }

  Widget _buildStep() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: KeyedSubtree(
        key: ValueKey(_currentStep),
        child: switch (_currentStep) {
          0 => _PersonalInfoStep(
            formKey: _personalKey, data: _personal,
            fullNameC: _fullNameC, cnicC: _cnicC,
          ),
          1 => _ContactInfoStep(
            formKey: _contactKey, data: _contact,
            phoneC: _phoneC, districtC: _districtC,
          ),
          2 => _DocumentsStep(
            docs: _docs,
            onPickProfile: () async {
              final f = await _pickSingleImage();
              if (f != null) setState(() => _docs.profileImage = f);
            },
          ),
          _ => _ReviewStep(
            personal: _personal, contact: _contact, docs: _docs,
            onEditStep: (s) => setState(() => _currentStep = s),
          ),
        },
      ),
    );
  }

  Widget _buildNavBar() {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(children: [
        if (_currentStep > 0) ...[
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: _goBack,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _C.border),
                foregroundColor: AppTheme.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Back', style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w500)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 3,
          child: ElevatedButton(
            style: AppTheme.primaryButton,
            onPressed: isLast ? _submit : _goNext,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLast ? 'Submit Application' : 'Continue',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(width: 6),
                Icon(isLast ? Icons.send_rounded : Icons.arrow_forward_ios,
                    size: isLast ? 16 : 13),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STEP PROGRESS BAR
// ─────────────────────────────────────────────────────────────
class _StepProgressBar extends StatelessWidget {
  final int currentStep, totalSteps;
  const _StepProgressBar({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    const labels = ['Personal', 'Contact', 'Document', 'Review'];
    const icons  = [
      Icons.person_outline, Icons.phone_outlined,
      Icons.folder_outlined, Icons.checklist_rounded,
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: List.generate(totalSteps, (i) {
          final isDone   = i < currentStep;
          final isActive = i == currentStep;
          return Expanded(
            child: Row(children: [
              Expanded(
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isDone || isActive) ? AppTheme.primaryGreen : _C.border,
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : Icon(icons[i],
                          color: isActive ? Colors.white : AppTheme.textSecondary,
                          size: 16),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: AppTheme.bodySmall.copyWith(
                      fontSize: 9,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive ? AppTheme.primaryGreen : AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
              if (i < totalSteps - 1)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 18),
                    color: isDone ? AppTheme.primaryGreen : _C.border,
                  ),
                ),
            ]),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STEP 1 – PERSONAL INFO
// ─────────────────────────────────────────────────────────────
class _PersonalInfoStep extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final _PersonalInfo         data;
  final TextEditingController fullNameC, cnicC;

  const _PersonalInfoStep({
    required this.formKey, required this.data,
    required this.fullNameC, required this.cnicC,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Form(
        key: formKey,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8), children: [
          _SectionHeader(icon: Icons.person, title: 'Personal Information',
              subtitle: 'Enter your details exactly as they appear on your CNIC'),
          const SizedBox(height: 20),
          _AppField(
            controller: fullNameC, label: 'Full Name', hint: 'As per CNIC',
            icon: Icons.person_outline,
            onChanged: (v) => data.fullName = v,
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Full name is required' : null,
          ),
          _AppField(
            controller: cnicC, label: 'CNIC Number', hint: '12345-1234567-1',
            icon: Icons.credit_card, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')), LengthLimitingTextInputFormatter(15)],
            onChanged: (v) => data.cnic = v,
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'CNIC is required';
              if (v!.replaceAll('-', '').length != 13) return 'Enter a valid 13-digit CNIC';
              return null;
            },
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STEP 2 – CONTACT INFO
// ─────────────────────────────────────────────────────────────
class _ContactInfoStep extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final _ContactInfo          data;
  final TextEditingController phoneC, districtC;

  const _ContactInfoStep({
    required this.formKey, required this.data,
    required this.phoneC, required this.districtC,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Form(
        key: formKey,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8), children: [
          _SectionHeader(icon: Icons.contact_phone, title: 'Contact Information',
              subtitle: 'Provide your current, reachable contact details'),
          const SizedBox(height: 20),
          _AppField(
            controller: phoneC, label: 'Phone Number', hint: '03XX-XXXXXXX',
            icon: Icons.phone_outlined, keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]'))],
            onChanged: (v) => data.phone = v,
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'Phone is required';
              if (v!.replaceAll('-', '').length < 10) return 'Enter a valid phone number';
              return null;
            },
          ),
          _AppField(
            controller: districtC, label: 'City / District', hint: 'e.g., Lahore',
            icon: Icons.location_on_outlined,
            onChanged: (v) => data.district = v,
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'City / District is required' : null,
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STEP 3 – DOCUMENT
// ─────────────────────────────────────────────────────────────
class _DocumentsStep extends StatelessWidget {
  final _DocumentSet docs;
  final VoidCallback onPickProfile;

  const _DocumentsStep({required this.docs, required this.onPickProfile});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        children: [
          _SectionHeader(icon: Icons.folder_copy, title: 'Profile Photo',
              subtitle: 'Upload a clear, recent photo of yourself'),
          const SizedBox(height: 8),
          _Banner(text: '⚠ Profile photo is mandatory to submit your application.', isWarning: true),
          const SizedBox(height: 16),
          _DocCard(
            label: 'Profile Photo', subtitle: 'A clear recent photo (JPG, PNG)',
            icon: Icons.person_pin, isRequired: true,
            isUploaded: docs.profileImage != null, uploadedCount: docs.profileImage != null ? 1 : 0,
            onTap: onPickProfile,
            preview: docs.profileImage != null ? _ImgPreview(file: docs.profileImage!) : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STEP 4 – REVIEW
// ─────────────────────────────────────────────────────────────
class _ReviewStep extends StatelessWidget {
  final _PersonalInfo     personal;
  final _ContactInfo      contact;
  final _DocumentSet      docs;
  final ValueChanged<int> onEditStep;

  const _ReviewStep({
    required this.personal, required this.contact,
    required this.docs, required this.onEditStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8), children: [
        _SectionHeader(icon: Icons.checklist_rounded, title: 'Review Application',
            subtitle: 'Please verify all details before submitting'),
        const SizedBox(height: 20),

        _ReviewCard(title: 'Personal Information', stepIndex: 0, onEdit: onEditStep, rows: [
          _RRow('Full Name', personal.fullName),
          _RRow('CNIC',      personal.cnic),
        ]),
        _ReviewCard(title: 'Contact Information', stepIndex: 1, onEdit: onEditStep, rows: [
          _RRow('Phone',    contact.phone),
          _RRow('District', contact.district),
        ]),
        _ReviewCard(title: 'Document', stepIndex: 2, onEdit: onEditStep, rows: [
          _RRow('Profile Photo', docs.profileImage != null ? '✓ Uploaded' : '✗ Missing',
              positive: docs.profileImage != null),
        ]),

        // Declaration
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.lightGreen,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.4)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, color: AppTheme.primaryGreen, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'By submitting, you confirm that all provided information is accurate. '
                    'Your application will be reviewed within 3–5 working days.',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryGreen, height: 1.5),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SUCCESS VIEW
// ─────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 100, height: 100,
              decoration: const BoxDecoration(color: AppTheme.lightGreen, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 56),
            ),
            const SizedBox(height: 28),
            Text('Application Submitted!', style: AppTheme.heading, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Your membership application has been received. We will review it within '
                  '3–5 working days and notify you of the outcome.',
              style: AppTheme.bodySmall.copyWith(height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: AppTheme.primaryButton,
              onPressed: onDone,
              child: const Text('Back to Home',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  UPLOAD OVERLAY
// ─────────────────────────────────────────────────────────────
class _UploadOverlay extends StatelessWidget {
  final double progress;
  final String status;
  const _UploadOverlay({required this.progress, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.82,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 3),
            const SizedBox(height: 20),
            Text('Submitting Application',
                style: AppTheme.subHeading.copyWith(fontSize: 17)),
            const SizedBox(height: 8),
            Text(status, style: AppTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress, backgroundColor: _C.border,
                color: AppTheme.primaryGreen, minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text('${(progress * 100).toInt()}%',
                style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   title, subtitle;
  const _SectionHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppTheme.primaryGreen, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,    style: AppTheme.subHeading.copyWith(fontSize: 17)),
          const SizedBox(height: 3),
          Text(subtitle, style: AppTheme.bodySmall.copyWith(height: 1.4)),
        ]),
      ),
    ]);
  }
}

/// Text field — explicitly white filled, green focus border
class _AppField extends StatelessWidget {
  final TextEditingController      controller;
  final String                     label, hint;
  final IconData                   icon;
  final int                        maxLines;
  final TextInputType              keyboardType;
  final List<TextInputFormatter>?  inputFormatters;
  final ValueChanged<String>?      onChanged;
  final FormFieldValidator<String>? validator;

  const _AppField({
    required this.controller, required this.label, required this.hint, required this.icon,
    this.maxLines = 1, this.keyboardType = TextInputType.text,
    this.inputFormatters, this.onChanged, this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        validator: validator,
        style: AppTheme.bodyLarge.copyWith(color: Colors.black87),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: label,
          hintText: hint,
          hintStyle: AppTheme.bodySmall.copyWith(color: Colors.black38),
          labelStyle: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
          prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _C.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.criticalRed),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.criticalRed, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Info / warning banner
class _Banner extends StatelessWidget {
  final String text;
  final bool   isWarning;
  const _Banner({required this.text, this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? _C.warningText  : AppTheme.primaryGreen;
    final bg    = isWarning ? _C.warningBg    : _C.infoBg;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(text, style: AppTheme.bodySmall.copyWith(color: color, height: 1.5)),
    );
  }
}

/// Document upload card
class _DocCard extends StatelessWidget {
  final String    label, subtitle;
  final IconData  icon;
  final bool      isRequired, isUploaded;
  final int       uploadedCount;
  final VoidCallback onTap;
  final Widget?   preview;

  const _DocCard({
    required this.label,       required this.subtitle,
    required this.icon,        required this.isRequired,
    required this.isUploaded,  required this.uploadedCount,
    required this.onTap,       this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isUploaded
        ? AppTheme.primaryGreen
        : isRequired ? AppTheme.criticalRed.withOpacity(0.4) : _C.border;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isUploaded ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isUploaded ? AppTheme.lightGreen : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isUploaded ? Icons.check : icon, size: 20,
                color: isUploaded ? AppTheme.primaryGreen : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(label, style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                  ),
                  if (isRequired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isUploaded
                            ? AppTheme.lightGreen
                            : AppTheme.criticalRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isUploaded ? 'Done' : 'Required',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: isUploaded ? AppTheme.primaryGreen : AppTheme.criticalRed,
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTheme.bodySmall.copyWith(fontSize: 12)),
              ]),
            ),
          ]),
        ),
        if (preview != null) ...[
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(12), child: preview),
        ],
        const Divider(height: 1),
        InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(isUploaded ? Icons.refresh : Icons.upload_file,
                  size: 16, color: AppTheme.primaryGreen),
              const SizedBox(width: 6),
              Text(
                isUploaded ? 'Replace Photo' : 'Tap to Upload',
                style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ImgPreview extends StatelessWidget {
  final File file;
  const _ImgPreview({required this.file});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.file(file, height: 120, width: double.infinity, fit: BoxFit.cover),
  );
}

// ─────────────────────────────────────────────────────────────
//  REVIEW CARD & ROW
// ─────────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final String        title;
  final int           stepIndex;
  final ValueChanged<int> onEdit;
  final List<_RRow>   rows;

  const _ReviewCard({
    required this.title, required this.stepIndex,
    required this.onEdit, required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(children: [
            Text(title, style: AppTheme.subHeading.copyWith(fontSize: 15, color: Colors.black87)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => onEdit(stepIndex),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Edit', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.all(16), child: Column(children: rows)),
      ]),
    );
  }
}

class _RRow extends StatelessWidget {
  final String label, value;
  final bool?  positive;
  const _RRow(this.label, this.value, {this.positive});

  @override
  Widget build(BuildContext context) {
    final Color col = positive == true
        ? AppTheme.primaryGreen
        : positive == false
        ? AppTheme.criticalRed
        : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(label, style: AppTheme.bodySmall.copyWith(color: Colors.black54))),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600, color: col),
          ),
        ),
      ]),
    );
  }
}















//
//
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:mukammalpakistanparty/%20config/app_theme.dart';
//
//
// // ─────────────────────────────────────────────────────────────
// //  LOCAL HELPERS  (only things AppTheme doesn't cover)
// // ─────────────────────────────────────────────────────────────
// class _C {
//   static const border      = Color(0xFFE0E0E0);
//   static const infoBg      = Color(0xFFE8F5E9); // soft green tint
//   static const warningBg   = Color(0xFFFFFDE7);
//   static const warningText = Color(0xFFF57F17);
// }
//
// // ─────────────────────────────────────────────────────────────
// //  DATA MODELS
// // ─────────────────────────────────────────────────────────────
// class _PersonalInfo {
//   String fullName   = '';
//   String fatherName = '';
//   String cnic       = '';
//   String gender     = '';
//   DateTime? dob;
// }
//
// class _ContactInfo {
//   String phone   = '';
//   String address = '';
//   String city    = '';
//   String email   = '';
// }
//
// class _EducationInfo {
//   String educationLevel   = '';
//   String institution      = '';
//   String yearOfCompletion = '';
//   String profession       = '';
//   String selectedRole    = '';
//
// }
//
// class _DocumentSet {
//   File?      profileImage;
//   List<File> cnicImages          = [];
//   File?      educationCertificate;
//   List<File> otherDocuments      = [];
// }
//
// // ─────────────────────────────────────────────────────────────
// //  MAIN SCREEN
// // ─────────────────────────────────────────────────────────────
// class MembershipApplicationScreen extends StatefulWidget {
//   final String userId;
//   const MembershipApplicationScreen({super.key, required this.userId});
//
//   @override
//   State<MembershipApplicationScreen> createState() =>
//       _MembershipApplicationScreenState();
// }
//
// class _MembershipApplicationScreenState
//     extends State<MembershipApplicationScreen> {
// // ADD THIS INSIDE _MembershipApplicationScreenState
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchRoles();
//   }
//
//   Future<void> _fetchRoles() async {
//     try {
//       final snapshot =
//       await FirebaseFirestore.instance.collection('roles').get();
//
//       final roles = snapshot.docs.map((e) => e.id).toList();
//
//       setState(() {
//         _roles = roles;
//         _rolesLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _rolesLoading = false;
//       });
//
//       _snack('Failed to load roles');
//     }
//   }
//   int _currentStep = 0;
//   static const int _totalSteps = 5;
//
//   final _personalKey  = GlobalKey<FormState>();
//   final _contactKey   = GlobalKey<FormState>();
//   final _educationKey = GlobalKey<FormState>();
//
//   final _personal  = _PersonalInfo();
//   final _contact   = _ContactInfo();
//   final _education = _EducationInfo();
//   final _docs      = _DocumentSet();
//
//   final _fullNameC    = TextEditingController();
//   final _fatherNameC  = TextEditingController();
//   final _cnicC        = TextEditingController();
//   final _phoneC       = TextEditingController();
//   final _addressC     = TextEditingController();
//   final _cityC        = TextEditingController();
//   final _emailC       = TextEditingController();
//   final _institutionC = TextEditingController();
//   final _yearC        = TextEditingController();
//
//   bool   _isSubmitting   = false;
//   double _uploadProgress = 0.0;
//   String _uploadStatus   = '';
//   bool   _submitted      = false;
//
//   final _genderOptions = ['Male', 'Female', 'Prefer not to say'];
//   final _educationLevels = [
//     'Matric (SSC)', 'Intermediate (HSSC)', 'Bachelor\'s Degree',
//     'Master\'s Degree', 'M.Phil / PhD', 'Diploma / Certificate', 'Other',
//   ];
//   final _professionOptions = [
//
//     'Student', 'Teacher / Educator', 'Engineer', 'Doctor / Healthcare',
//     'Lawyer', 'Businessman', 'Government Employee', 'Politician',
//     'Journalist', 'Social Worker', 'Other',
//   ];
//   List<String> _roles = [];
//   bool _rolesLoading = true;
//   @override
//   void dispose() {
//     _fullNameC.dispose();  _fatherNameC.dispose(); _cnicC.dispose();
//     _phoneC.dispose();     _addressC.dispose();    _cityC.dispose();
//     _emailC.dispose();     _institutionC.dispose(); _yearC.dispose();
//     super.dispose();
//   }
//
//   // ── Navigation ───────────────────────────────────────────────
//   void _goNext() {
//     if (_currentStep == 0 && !_validatePersonal())  return;
//     if (_currentStep == 1 && !_validateContact())   return;
//     if (_currentStep == 2 && !_validateEducation()) return;
//     if (_currentStep == 3 && !_validateDocuments()) return;
//     if (_currentStep < _totalSteps - 1) setState(() => _currentStep++);
//   }
//
//   void _goBack() {
//     if (_currentStep > 0) setState(() => _currentStep--);
//   }
//
//   // ── Validation ───────────────────────────────────────────────
//   bool _validatePersonal() {
//     if (!(_personalKey.currentState?.validate() ?? false)) return false;
//     if (_personal.gender.isEmpty) { _snack('Please select your gender');       return false; }
//     if (_personal.dob == null)    { _snack('Please select your date of birth'); return false; }
//     return true;
//   }
//   bool _validateContact()   => _contactKey.currentState?.validate()   ?? false;
//   bool _validateEducation() {
//     if (!(_educationKey.currentState?.validate() ?? false)) return false;
//
//     if (_education.educationLevel.isEmpty) {
//       _snack('Please select education level');
//       return false;
//     }
//
//     if (_education.profession.isEmpty) {
//       _snack('Please select profession');
//       return false;
//     }
//
//     if (_education.selectedRole.isEmpty) {
//       _snack('Please select role');
//       return false;
//     }
//
//     return true;
//   }
//   bool _validateDocuments() {
//     if (_docs.profileImage == null)         { _snack('Profile image is required');          return false; }
//     if (_docs.cnicImages.isEmpty)           { _snack('CNIC / ID card images are required'); return false; }
//     if (_docs.educationCertificate == null) { _snack('Education certificate is required');  return false; }
//     return true;
//   }
//
//   void _snack(String msg, {bool error = true}) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       content: Row(children: [
//         Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 18),
//         const SizedBox(width: 8),
//         Expanded(child: Text(msg)),
//       ]),
//       backgroundColor: error ? AppTheme.criticalRed : AppTheme.primaryGreen,
//       behavior: SnackBarBehavior.floating,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       margin: const EdgeInsets.all(16),
//     ));
//   }
//
//   // ── File pickers ─────────────────────────────────────────────
//   Future<File?> _pickSingleImage() async {
//     final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
//     return p == null ? null : File(p.path);
//   }
//   Future<List<File>> _pickMultipleImages() async {
//     final list = await ImagePicker().pickMultiImage(imageQuality: 85);
//     return list.map((e) => File(e.path)).toList();
//   }
//   Future<File?> _pickAnyFile() async {
//     final r = await FilePicker.platform.pickFiles(
//         type: FileType.custom, allowedExtensions: ['pdf','jpg','jpeg','png','doc','docx']);
//     return r == null ? null : File(r.files.single.path!);
//   }
//   Future<List<File>> _pickMultipleFiles() async {
//     final r = await FilePicker.platform.pickFiles(
//         allowMultiple: true, type: FileType.custom,
//         allowedExtensions: ['pdf','jpg','jpeg','png','doc','docx']);
//     if (r == null) return [];
//     return r.paths.where((p) => p != null).map((p) => File(p!)).toList();
//   }
//
//   // ── Upload ───────────────────────────────────────────────────
//   Future<String> _uploadFile(File file, String path) async {
//     final task = FirebaseStorage.instance.ref().child(path).putFile(file);
//     task.snapshotEvents.listen((e) {
//       if (e.totalBytes > 0) setState(() => _uploadProgress = e.bytesTransferred / e.totalBytes);
//     });
//     return (await task).ref.getDownloadURL();
//   }
//
//   // ── Submit ───────────────────────────────────────────────────
//   Future<void> _submit() async {
//     if (!_validateDocuments()) return;
//     setState(() { _isSubmitting = true; _uploadProgress = 0; });
//
//     try {
//       final uid = widget.userId;
//       final ts  = DateTime.now().millisecondsSinceEpoch;
//
//       setState(() => _uploadStatus = 'Uploading profile image…');
//       final profileUrl = await _uploadFile(_docs.profileImage!, 'memberships/$uid/profile_$ts.jpg');
//
//       setState(() => _uploadStatus = 'Uploading ID card images…');
//       final cnicUrls = <String>[];
//       for (int i = 0; i < _docs.cnicImages.length; i++) {
//         cnicUrls.add(await _uploadFile(_docs.cnicImages[i], 'memberships/$uid/cnic_${i}_$ts.jpg'));
//       }
//
//       setState(() => _uploadStatus = 'Uploading education certificate…');
//       final ext = _docs.educationCertificate!.path.split('.').last;
//       final certUrl = await _uploadFile(_docs.educationCertificate!, 'memberships/$uid/certificate_$ts.$ext');
//
//       final otherUrls = <String>[];
//       if (_docs.otherDocuments.isNotEmpty) {
//         setState(() => _uploadStatus = 'Uploading supporting documents…');
//         for (int i = 0; i < _docs.otherDocuments.length; i++) {
//           final ex = _docs.otherDocuments[i].path.split('.').last;
//           otherUrls.add(await _uploadFile(_docs.otherDocuments[i], 'memberships/$uid/other_${i}_$ts.$ex'));
//         }
//       }
//
//       setState(() => _uploadStatus = 'Saving application…');
//       await FirebaseFirestore.instance.collection('membership_applications').add({
//         'user_id': uid,
//         'personal_info': {
//           'full_name':     _personal.fullName,
//           'father_name':   _personal.fatherName,
//           'cnic':          _personal.cnic,
//           'gender':        _personal.gender,
//           'date_of_birth': Timestamp.fromDate(_personal.dob!),
//         },
//         'contact_info': {
//           'phone':   _contact.phone,
//           'address': _contact.address,
//           'city':    _contact.city,
//           'email':   _contact.email.isEmpty ? null : _contact.email,
//         },
//         'education_info': {
//           'education_level':    _education.educationLevel,
//           'institution':        _education.institution,
//           'year_of_completion': _education.yearOfCompletion,
//           'profession':         _education.profession,
//           'selected_role': _education.selectedRole,
//         },
//         'documents': {
//           'profile_image':         profileUrl,
//           'cnic_images':           cnicUrls,
//           'education_certificate': certUrl,
//           'other_documents':       otherUrls,
//         },
//         'status':       'pending',
//         'submitted_at': FieldValue.serverTimestamp(),
//         'reviewed_at':  null,
//         'reviewed_by':  null,
//       });
//
//       setState(() { _submitted = true; _isSubmitting = false; });
//     } catch (e) {
//       setState(() => _isSubmitting = false);
//       _snack('Submission failed: $e');
//     }
//   }
//
//   // ── Build ────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     if (_submitted) return _SuccessView(onDone: () => Navigator.pop(context));
//
//     return Scaffold(
//       backgroundColor: Colors.white, // ← FIX: explicit white, overrides any dark theme scaffold color
//       appBar: _buildAppBar(),
//       body: Stack(
//         children: [
//           Column(children: [
//             _StepProgressBar(currentStep: _currentStep, totalSteps: _totalSteps),
//             Expanded(child: _buildStep()),
//             _buildNavBar(),
//           ]),
//           if (_isSubmitting)
//             _UploadOverlay(progress: _uploadProgress, status: _uploadStatus),
//         ],
//       ),
//     );
//   }
//
//   // AppBar uses AppTheme.appBarTheme: green bg, white fg, centered
//   AppBar _buildAppBar() {
//     const titles = ['Personal Info','Contact Info','Education','Documents','Review & Submit'];
//     return AppBar(
//       backgroundColor: AppTheme.primaryGreen, // ← FIX: explicit green so it's never dark
//       foregroundColor: Colors.white,
//       elevation: 0,
//       leading: _currentStep > 0
//           ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: _goBack)
//           : IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
//       title: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(titles[_currentStep],
//               style: AppTheme.subHeading.copyWith(color: AppTheme.textOnPrimary, fontSize: 16)),
//           Text('Step ${_currentStep + 1} of $_totalSteps',
//               style: AppTheme.bodySmall.copyWith(color: AppTheme.textOnPrimary.withOpacity(0.8), fontSize: 12)),
//         ],
//       ),
//       centerTitle: false,
//     );
//   }
//
//   Widget _buildStep() {
//     return AnimatedSwitcher(
//       duration: const Duration(milliseconds: 280),
//       transitionBuilder: (child, anim) => SlideTransition(
//         position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
//             .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
//         child: FadeTransition(opacity: anim, child: child),
//       ),
//       child: KeyedSubtree(
//         key: ValueKey(_currentStep),
//         child: switch (_currentStep) {
//           0 => _PersonalInfoStep(
//             formKey: _personalKey, data: _personal,
//             genderOptions: _genderOptions,
//             fullNameC: _fullNameC, fatherNameC: _fatherNameC, cnicC: _cnicC,
//             onDobSelected:    (d) => setState(() => _personal.dob    = d),
//             onGenderSelected: (g) => setState(() => _personal.gender = g),
//           ),
//           1 => _ContactInfoStep(
//             formKey: _contactKey, data: _contact,
//             phoneC: _phoneC, addressC: _addressC, cityC: _cityC, emailC: _emailC,
//           ),
//
//           2 => _EducationStep(
//             formKey: _educationKey,
//             data: _education,
//             educationLevels: _educationLevels,
//             professionOptions: _professionOptions,
//             roles: _roles,
//             rolesLoading: _rolesLoading,
//             institutionC: _institutionC,
//             yearC: _yearC,
//             onLevelSelected: (l) =>
//                 setState(() => _education.educationLevel = l),
//             onProfessionSelected: (p) =>
//                 setState(() => _education.profession = p),
//             onRoleSelected: (r) =>
//                 setState(() => _education.selectedRole = r),
//           ),
//           3 => _DocumentsStep(
//             docs: _docs,
//             onPickProfile: () async {
//               final f = await _pickSingleImage();
//               if (f != null) setState(() => _docs.profileImage = f);
//             },
//             onPickCnic: () async {
//               final fs = await _pickMultipleImages();
//               if (fs.isNotEmpty) setState(() => _docs.cnicImages = fs);
//             },
//             onPickCertificate: () async {
//               final f = await _pickAnyFile();
//               if (f != null) setState(() => _docs.educationCertificate = f);
//             },
//             onPickOther: () async {
//               final fs = await _pickMultipleFiles();
//               if (fs.isNotEmpty) setState(() => _docs.otherDocuments = fs);
//             },
//             onRemoveCnic:  (i) => setState(() => _docs.cnicImages.removeAt(i)),
//             onRemoveOther: (i) => setState(() => _docs.otherDocuments.removeAt(i)),
//           ),
//           _ => _ReviewStep(
//             personal: _personal, contact: _contact,
//             education: _education, docs: _docs,
//             onEditStep: (s) => setState(() => _currentStep = s),
//           ),
//         },
//       ),
//     );
//   }
//
//   Widget _buildNavBar() {
//     final isLast = _currentStep == _totalSteps - 1;
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white, // ← FIX: explicit white
//         border: Border(top: BorderSide(color: _C.border)),
//       ),
//       padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
//       child: Row(children: [
//         if (_currentStep > 0) ...[
//           Expanded(
//             flex: 2,
//             child: OutlinedButton(
//               onPressed: _goBack,
//               style: OutlinedButton.styleFrom(
//                 side: const BorderSide(color: _C.border),
//                 foregroundColor: AppTheme.textPrimary,
//                 padding: const EdgeInsets.symmetric(vertical: 14),
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//               ),
//               child: Text('Back', style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w500)),
//             ),
//           ),
//           const SizedBox(width: 12),
//         ],
//         Expanded(
//           flex: 3,
//           child: ElevatedButton(
//             style: AppTheme.primaryButton,
//             onPressed: isLast ? _submit : _goNext,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(
//                   isLast ? 'Submit Application' : 'Continue',
//                   style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
//                 ),
//                 const SizedBox(width: 6),
//                 Icon(isLast ? Icons.send_rounded : Icons.arrow_forward_ios,
//                     size: isLast ? 16 : 13),
//               ],
//             ),
//           ),
//         ),
//       ]),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────
// //  STEP PROGRESS BAR
// // ─────────────────────────────────────────────────────────────
// class _StepProgressBar extends StatelessWidget {
//   final int currentStep, totalSteps;
//   const _StepProgressBar({required this.currentStep, required this.totalSteps});
//
//   @override
//   Widget build(BuildContext context) {
//     const labels = ['Personal','Contact','Education','Documents','Review'];
//     const icons  = [
//       Icons.person_outline, Icons.phone_outlined, Icons.school_outlined,
//       Icons.folder_outlined, Icons.checklist_rounded,
//     ];
//     return Container(
//       color: Colors.white, // ← FIX: explicit white
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//       child: Row(
//         children: List.generate(totalSteps, (i) {
//           final isDone   = i < currentStep;
//           final isActive = i == currentStep;
//           return Expanded(
//             child: Row(children: [
//               Expanded(
//                 child: Column(children: [
//                   AnimatedContainer(
//                     duration: const Duration(milliseconds: 250),
//                     width: 32, height: 32,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: (isDone || isActive) ? AppTheme.primaryGreen : _C.border,
//                     ),
//                     child: Center(
//                       child: isDone
//                           ? const Icon(Icons.check, color: Colors.white, size: 16)
//                           : Icon(icons[i],
//                           color: isActive ? Colors.white : AppTheme.textSecondary,
//                           size: 16),
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     labels[i],
//                     style: AppTheme.bodySmall.copyWith(
//                       fontSize: 9,
//                       fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
//                       color: isActive ? AppTheme.primaryGreen : AppTheme.textSecondary,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ]),
//               ),
//               if (i < totalSteps - 1)
//                 Expanded(
//                   child: AnimatedContainer(
//                     duration: const Duration(milliseconds: 300),
//                     height: 2,
//                     margin: const EdgeInsets.only(bottom: 18),
//                     color: isDone ? AppTheme.primaryGreen : _C.border,
//                   ),
//                 ),
//             ]),
//           );
//         }),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────
// //  STEP 1 – PERSONAL INFO
// // ─────────────────────────────────────────────────────────────
// class _PersonalInfoStep extends StatefulWidget {
//   final GlobalKey<FormState>   formKey;
//   final _PersonalInfo          data;
//   final List<String>           genderOptions;
//   final TextEditingController  fullNameC, fatherNameC, cnicC;
//   final ValueChanged<DateTime> onDobSelected;
//   final ValueChanged<String>   onGenderSelected;
//
//   const _PersonalInfoStep({
//     required this.formKey, required this.data, required this.genderOptions,
//     required this.fullNameC, required this.fatherNameC, required this.cnicC,
//     required this.onDobSelected, required this.onGenderSelected,
//   });
//
//   @override
//   State<_PersonalInfoStep> createState() => _PersonalInfoStepState();
// }
//
// class _PersonalInfoStepState extends State<_PersonalInfoStep> {
//   String?   _gender;
//   DateTime? _dob;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _gender = widget.data.gender.isEmpty ? null : widget.data.gender;
//     _dob    = widget.data.dob;
//   }
//
//   String _fmt(DateTime d) =>
//       '${d.day.toString().padLeft(2,'0')} / ${d.month.toString().padLeft(2,'0')} / ${d.year}';
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: Colors.white, // ← FIX: explicit white background for the step
//       child: Form(
//         key: widget.formKey,
//         child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8), children: [
//           _SectionHeader(icon: Icons.person, title: 'Personal Information',
//               subtitle: 'Enter your details exactly as they appear on your CNIC'),
//           const SizedBox(height: 20),
//           _AppField(controller: widget.fullNameC,   label: 'Full Name',      hint: 'As per CNIC',
//               icon: Icons.person_outline,
//               onChanged: (v) => widget.data.fullName   = v,
//               validator: (v) => (v?.trim().isEmpty ?? true) ? 'Full name is required'   : null),
//           _AppField(controller: widget.fatherNameC, label: "Father's Name",  hint: 'As per CNIC',
//               icon: Icons.people_outline,
//               onChanged: (v) => widget.data.fatherName = v,
//               validator: (v) => (v?.trim().isEmpty ?? true) ? 'Father name is required' : null),
//           _AppField(
//             controller: widget.cnicC, label: 'CNIC Number', hint: '12345-1234567-1',
//             icon: Icons.credit_card, keyboardType: TextInputType.number,
//             inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')), LengthLimitingTextInputFormatter(15)],
//             onChanged: (v) => widget.data.cnic = v,
//             validator: (v) {
//               if (v?.trim().isEmpty ?? true) return 'CNIC is required';
//               if (v!.replaceAll('-','').length != 13) return 'Enter a valid 13-digit CNIC';
//               return null;
//             },
//           ),
//           _DropField<String>(
//             label: 'Gender', icon: Icons.wc_outlined, value: _gender,
//             items: widget.genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
//             onChanged: (v) { if (v==null) return; setState(()=>_gender=v); widget.onGenderSelected(v); },
//             validator: (v) => v == null ? 'Please select gender' : null,
//           ),
//           _DateField(
//             label: 'Date of Birth', icon: Icons.calendar_today_outlined,
//             displayText: _dob != null ? _fmt(_dob!) : null, hasValue: _dob != null,
//             onPick: () async {
//               final p = await showDatePicker(
//                 context: context,
//                 firstDate: DateTime(1920),
//                 lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
//                 initialDate: _dob ?? DateTime(1990),
//                 builder: (ctx, child) => Theme(
//                   data: Theme.of(ctx).copyWith(
//                     colorScheme: const ColorScheme.light(primary: AppTheme.primaryGreen),
//                   ),
//                   child: child!,
//                 ),
//               );
//               if (p != null) { setState(()=>_dob=p); widget.onDobSelected(p); }
//             },
//           ),
//         ]),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────
// //  STEP 2 – CONTACT INFO
// // ─────────────────────────────────────────────────────────────
// class _ContactInfoStep extends StatelessWidget {
//   final GlobalKey<FormState>  formKey;
//   final _ContactInfo          data;
//   final TextEditingController phoneC, addressC, cityC, emailC;
//
//   const _ContactInfoStep({
//     required this.formKey, required this.data,
//     required this.phoneC,  required this.addressC,
//     required this.cityC,   required this.emailC,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: Colors.white, // ← FIX: explicit white background for the step
//       child: Form(
//         key: formKey,
//         child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8), children: [
//           _SectionHeader(icon: Icons.contact_phone, title: 'Contact Information',
//               subtitle: 'Provide your current, reachable contact details'),
//           const SizedBox(height: 20),
//           _AppField(
//             controller: phoneC, label: 'Phone Number', hint: '03XX-XXXXXXX',
//             icon: Icons.phone_outlined, keyboardType: TextInputType.phone,
//             inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]'))],
//             onChanged: (v) => data.phone = v,
//             validator: (v) {
//               if (v?.trim().isEmpty ?? true) return 'Phone is required';
//               if (v!.replaceAll('-','').length < 10) return 'Enter a valid phone number';
//               return null;
//             },
//           ),
//           _AppField(
//             controller: addressC, label: 'Home Address', hint: 'Street, House No., Area',
//             icon: Icons.home_outlined, maxLines: 3,
//             onChanged: (v) => data.address = v,
//             validator: (v) => (v?.trim().isEmpty ?? true) ? 'Address is required' : null,
//           ),
//           _AppField(
//             controller: cityC, label: 'City', hint: 'e.g., Lahore',
//             icon: Icons.location_city_outlined,
//             onChanged: (v) => data.city = v,
//             validator: (v) => (v?.trim().isEmpty ?? true) ? 'City is required' : null,
//           ),
//           _AppField(
//             controller: emailC, label: 'Email Address (Optional)', hint: 'example@email.com',
//             icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress,
//             onChanged: (v) => data.email = v,
//             validator: (v) {
//               if (v == null || v.trim().isEmpty) return null;
//               if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return 'Enter a valid email';
//               return null;
//             },
//           ),
//           _Banner(text: 'Email is optional but recommended for application status updates.'),
//         ]),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────
// //  STEP 3 – EDUCATION
// // ─────────────────────────────────────────────────────────────
// // REPLACE YOUR ENTIRE _EducationStep CLASS WITH THIS COMPLETE VERSION
//
// class _EducationStep extends StatefulWidget {
//   final GlobalKey<FormState> formKey;
//   final _EducationInfo data;
//
//   final List<String> educationLevels;
//   final List<String> professionOptions;
//
//   final List<String> roles;
//   final bool rolesLoading;
//
//   final TextEditingController institutionC;
//   final TextEditingController yearC;
//
//   final ValueChanged<String> onLevelSelected;
//   final ValueChanged<String> onProfessionSelected;
//   final ValueChanged<String> onRoleSelected;
//
//   const _EducationStep({
//     super.key,
//     required this.formKey,
//     required this.data,
//     required this.educationLevels,
//     required this.professionOptions,
//     required this.roles,
//     required this.rolesLoading,
//     required this.institutionC,
//     required this.yearC,
//     required this.onLevelSelected,
//     required this.onProfessionSelected,
//     required this.onRoleSelected,
//   });
//
//   @override
//   State<_EducationStep> createState() => _EducationStepState();
// }
//
// class _EducationStepState extends State<_EducationStep> {
//   String? _role;
//   String? _level;
//   String? _profession;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _level = widget.data.educationLevel.isEmpty
//         ? null
//         : widget.data.educationLevel;
//
//     _profession = widget.data.profession.isEmpty
//         ? null
//         : widget.data.profession;
//
//     _role = widget.data.selectedRole.isEmpty
//         ? null
//         : widget.data.selectedRole;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: Colors.white,
//       child: Form(
//         key: widget.formKey,
//         child: ListView(
//           padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
//           children: [
//             _SectionHeader(
//               icon: Icons.school,
//               title: 'Educational Background',
//               subtitle:
//               'Your highest completed education and current profession',
//             ),
//
//             const SizedBox(height: 20),
//
//             _DropField<String>(
//               label: 'Highest Education Level',
//               icon: Icons.school_outlined,
//               value: _level,
//               items: widget.educationLevels
//                   .map(
//                     (e) => DropdownMenuItem<String>(
//                   value: e,
//                   child: Text(e),
//                 ),
//               )
//                   .toList(),
//               onChanged: (v) {
//                 if (v == null) return;
//
//                 setState(() => _level = v);
//
//                 widget.onLevelSelected(v);
//               },
//               validator: (v) {
//                 if (v == null || v.isEmpty) {
//                   return 'Please select education level';
//                 }
//
//                 return null;
//               },
//             ),
//
//             _AppField(
//               controller: widget.institutionC,
//               label: 'Institution / University Name',
//               hint: 'e.g., University of Punjab',
//               icon: Icons.account_balance_outlined,
//               onChanged: (v) {
//                 widget.data.institution = v;
//               },
//               validator: (v) {
//                 if (v?.trim().isEmpty ?? true) {
//                   return 'Institution name is required';
//                 }
//
//                 return null;
//               },
//             ),
//
//             _AppField(
//               controller: widget.yearC,
//               label: 'Year of Completion',
//               hint: 'e.g., 2020',
//               icon: Icons.calendar_month_outlined,
//               keyboardType: TextInputType.number,
//               inputFormatters: [
//                 FilteringTextInputFormatter.digitsOnly,
//                 LengthLimitingTextInputFormatter(4),
//               ],
//               onChanged: (v) {
//                 widget.data.yearOfCompletion = v;
//               },
//               validator: (v) {
//                 if (v?.trim().isEmpty ?? true) {
//                   return 'Year is required';
//                 }
//
//                 final y = int.tryParse(v!);
//
//                 if (y == null ||
//                     y < 1960 ||
//                     y > DateTime.now().year) {
//                   return 'Enter a valid year';
//                 }
//
//                 return null;
//               },
//             ),
//
//             _DropField<String>(
//               label: 'Current Profession',
//               icon: Icons.work_outline,
//               value: _profession,
//               items: widget.professionOptions
//                   .map(
//                     (p) => DropdownMenuItem<String>(
//                   value: p,
//                   child: Text(p),
//                 ),
//               )
//                   .toList(),
//               onChanged: (v) {
//                 if (v == null) return;
//
//                 setState(() => _profession = v);
//
//                 widget.onProfessionSelected(v);
//               },
//               validator: (v) {
//                 if (v == null || v.isEmpty) {
//                   return 'Please select profession';
//                 }
//
//                 return null;
//               },
//             ),
//
//             if (widget.rolesLoading)
//               const Padding(
//                 padding: EdgeInsets.symmetric(vertical: 20),
//                 child: Center(
//                   child: CircularProgressIndicator(
//                     color: AppTheme.primaryGreen,
//                   ),
//                 ),
//               )
//             else
//               _DropField<String>(
//                 label: 'Select Role',
//                 icon: Icons.admin_panel_settings_outlined,
//                 value: _role,
//                 items: widget.roles
//                     .map(
//                       (r) => DropdownMenuItem<String>(
//                     value: r,
//                     child: Text(r),
//                   ),
//                 )
//                     .toList(),
//                 onChanged: (v) {
//                   if (v == null) return;
//
//                   setState(() => _role = v);
//
//                   widget.onRoleSelected(v);
//                 },
//                 validator: (v) {
//                   if (v == null || v.isEmpty) {
//                     return 'Please select role';
//                   }
//
//                   return null;
//                 },
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────
// //  STEP 4 – DOCUMENTS
// // ─────────────────────────────────────────────────────────────
// class _DocumentsStep extends StatelessWidget {
//   final _DocumentSet      docs;
//   final VoidCallback      onPickProfile, onPickCnic, onPickCertificate, onPickOther;
//   final ValueChanged<int> onRemoveCnic, onRemoveOther;
//
//   const _DocumentsStep({
//     required this.docs,
//     required this.onPickProfile, required this.onPickCnic,
//     required this.onPickCertificate, required this.onPickOther,
//     required this.onRemoveCnic, required this.onRemoveOther,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: Colors.white, // ← FIX: explicit white background for the step
//       child: ListView(
//         padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
//         children: [
//           _SectionHeader(icon: Icons.folder_copy, title: 'Required Documents',
//               subtitle: 'Upload clear, readable copies of all required documents'),
//           const SizedBox(height: 8),
//           _Banner(text: '⚠ Profile image, CNIC images, and education certificate are mandatory.', isWarning: true),
//           const SizedBox(height: 16),
//
//           _DocCard(
//             label: 'Profile Photo', subtitle: 'A clear recent photo (JPG, PNG)',
//             icon: Icons.person_pin, isRequired: true,
//             isUploaded: docs.profileImage != null, uploadedCount: docs.profileImage != null ? 1 : 0,
//             onTap: onPickProfile,
//             preview: docs.profileImage != null ? _ImgPreview(file: docs.profileImage!) : null,
//           ),
//           const SizedBox(height: 12),
//           _DocCard(
//             label: 'CNIC / National ID Card',
//             subtitle: 'Front & back of your ID card (multiple images allowed)',
//             icon: Icons.credit_card, isRequired: true,
//             isUploaded: docs.cnicImages.isNotEmpty, uploadedCount: docs.cnicImages.length,
//             onTap: onPickCnic,
//             preview: docs.cnicImages.isNotEmpty
//                 ? _MultiImgPreview(files: docs.cnicImages, onRemove: onRemoveCnic)
//                 : null,
//           ),
//           const SizedBox(height: 12),
//           _DocCard(
//             label: 'Education Certificate / Degree',
//             subtitle: 'Scanned copy of your highest degree (PDF, JPG, PNG)',
//             icon: Icons.workspace_premium_outlined, isRequired: true,
//             isUploaded: docs.educationCertificate != null,
//             uploadedCount: docs.educationCertificate != null ? 1 : 0,
//             onTap: onPickCertificate,
//             preview: docs.educationCertificate != null ? _FileNamePreview(file: docs.educationCertificate!) : null,
//           ),
//           const SizedBox(height: 20),
//
//           Row(children: [
//             const Expanded(child: Divider()),
//             Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
//                 child: Text('Optional Documents', style: AppTheme.bodySmall.copyWith(fontSize: 12))),
//             const Expanded(child: Divider()),
//           ]),
//           const SizedBox(height: 12),
//
//           _DocCard(
//             label: 'Supporting Documents',
//             subtitle: 'Any other relevant certificates or references (optional)',
//             icon: Icons.attach_file, isRequired: false,
//             isUploaded: docs.otherDocuments.isNotEmpty, uploadedCount: docs.otherDocuments.length,
//             onTap: onPickOther,
//             preview: docs.otherDocuments.isNotEmpty
//                 ? _MultiFilePreview(files: docs.otherDocuments, onRemove: onRemoveOther)
//                 : null,
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────
// //  STEP 5 – REVIEW
// // ─────────────────────────────────────────────────────────────
// class _ReviewStep extends StatelessWidget {
//   final _PersonalInfo     personal;
//   final _ContactInfo      contact;
//   final _EducationInfo    education;
//   final _DocumentSet      docs;
//   final ValueChanged<int> onEditStep;
//
//   const _ReviewStep({
//     required this.personal, required this.contact,
//     required this.education, required this.docs, required this.onEditStep,
//   });
//
//   String _fmt(DateTime? d) => d == null
//       ? '—'
//       : '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: Colors.white, // ← FIX: explicit white background for the step
//       child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8), children: [
//         _SectionHeader(icon: Icons.checklist_rounded, title: 'Review Application',
//             subtitle: 'Please verify all details before submitting'),
//         const SizedBox(height: 20),
//
//         _ReviewCard(title: 'Personal Information', stepIndex: 0, onEdit: onEditStep, rows: [
//           _RRow('Full Name',    personal.fullName),
//           _RRow('Father Name',  personal.fatherName),
//           _RRow('CNIC',         personal.cnic),
//           _RRow('Gender',       personal.gender),
//           _RRow('Date of Birth', _fmt(personal.dob)),
//         ]),
//         _ReviewCard(title: 'Contact Information', stepIndex: 1, onEdit: onEditStep, rows: [
//           _RRow('Phone',   contact.phone),
//           _RRow('Address', contact.address),
//           _RRow('City',    contact.city),
//           _RRow('Email',   contact.email.isEmpty ? 'Not provided' : contact.email),
//         ]),
//         _ReviewCard(title: 'Educational Background', stepIndex: 2, onEdit: onEditStep, rows: [
//           _RRow('Education',   education.educationLevel),
//           _RRow('Institution', education.institution),
//           _RRow('Year',        education.yearOfCompletion),
//           _RRow('Profession',  education.profession),
//         ]),
//         _ReviewCard(title: 'Documents', stepIndex: 3, onEdit: onEditStep, rows: [
//           _RRow('Profile Photo', docs.profileImage != null          ? '✓ Uploaded'                         : '✗ Missing',  positive: docs.profileImage != null),
//           _RRow('CNIC Images',   docs.cnicImages.isNotEmpty          ? '✓ ${docs.cnicImages.length} image(s)' : '✗ Missing',  positive: docs.cnicImages.isNotEmpty),
//           _RRow('Certificate',   docs.educationCertificate != null   ? '✓ Uploaded'                         : '✗ Missing',  positive: docs.educationCertificate != null),
//           _RRow('Other Docs',    docs.otherDocuments.isEmpty ? 'None' : '${docs.otherDocuments.length} file(s)'),
//         ]),
//
//         // Declaration
//         Container(
//           margin: const EdgeInsets.only(top: 4),
//           padding: const EdgeInsets.all(14),
//           decoration: BoxDecoration(
//             color: AppTheme.lightGreen,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.4)),
//           ),
//           child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//             const Icon(Icons.info_outline, color: AppTheme.primaryGreen, size: 18),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Text(
//                 'By submitting, you confirm that all provided information is accurate. '
//                     'Your application will be reviewed within 3–5 working days.',
//                 style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryGreen, height: 1.5),
//               ),
//             ),
//           ]),
//         ),
//         const SizedBox(height: 8),
//       ]),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────
// //  SUCCESS VIEW
// // ─────────────────────────────────────────────────────────────
// class _SuccessView extends StatelessWidget {
//   final VoidCallback onDone;
//   const _SuccessView({required this.onDone});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white, // ← FIX: explicit white
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(32),
//           child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//             Container(
//               width: 100, height: 100,
//               decoration: const BoxDecoration(color: AppTheme.lightGreen, shape: BoxShape.circle),
//               child: const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 56),
//             ),
//             const SizedBox(height: 28),
//             Text('Application Submitted!', style: AppTheme.heading, textAlign: TextAlign.center),
//             const SizedBox(height: 12),
//             Text(
//               'Your membership application has been received. We will review it within '
//                   '3–5 working days and notify you of the outcome.',
//               style: AppTheme.bodySmall.copyWith(height: 1.6),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 40),
//             ElevatedButton(
//               style: AppTheme.primaryButton,
//               onPressed: onDone,
//               child: const Text('Back to Home',
//                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//             ),
//           ]),
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────
// //  UPLOAD OVERLAY
// // ─────────────────────────────────────────────────────────────
// class _UploadOverlay extends StatelessWidget {
//   final double progress;
//   final String status;
//   const _UploadOverlay({required this.progress, required this.status});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: Colors.black54,
//       child: Center(
//         child: Container(
//           width: MediaQuery.of(context).size.width * 0.82,
//           padding: const EdgeInsets.all(28),
//           decoration: BoxDecoration(
//               color: Colors.white, // ← FIX: explicit white
//               borderRadius: BorderRadius.circular(20)),
//           child: Column(mainAxisSize: MainAxisSize.min, children: [
//             const CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 3),
//             const SizedBox(height: 20),
//             Text('Submitting Application',
//                 style: AppTheme.subHeading.copyWith(fontSize: 17)),
//             const SizedBox(height: 8),
//             Text(status, style: AppTheme.bodySmall, textAlign: TextAlign.center),
//             const SizedBox(height: 16),
//             ClipRRect(
//               borderRadius: BorderRadius.circular(8),
//               child: LinearProgressIndicator(
//                 value: progress, backgroundColor: _C.border,
//                 color: AppTheme.primaryGreen, minHeight: 8,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text('${(progress * 100).toInt()}%',
//                 style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600)),
//           ]),
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────
// //  SHARED WIDGETS
// // ─────────────────────────────────────────────────────────────
//
// class _SectionHeader extends StatelessWidget {
//   final IconData icon;
//   final String   title, subtitle;
//   const _SectionHeader({required this.icon, required this.title, required this.subtitle});
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Container(
//         padding: const EdgeInsets.all(10),
//         decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(10)),
//         child: Icon(icon, color: AppTheme.primaryGreen, size: 22),
//       ),
//       const SizedBox(width: 14),
//       Expanded(
//         child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Text(title,    style: AppTheme.subHeading.copyWith(fontSize: 17)),
//           const SizedBox(height: 3),
//           Text(subtitle, style: AppTheme.bodySmall.copyWith(height: 1.4)),
//         ]),
//       ),
//     ]);
//   }
// }
//
// /// Text field — explicitly white filled, green focus border
// class _AppField extends StatelessWidget {
//   final TextEditingController      controller;
//   final String                     label, hint;
//   final IconData                   icon;
//   final int                        maxLines;
//   final TextInputType              keyboardType;
//   final List<TextInputFormatter>?  inputFormatters;
//   final ValueChanged<String>?      onChanged;
//   final FormFieldValidator<String>? validator;
//
//   const _AppField({
//     required this.controller, required this.label, required this.hint, required this.icon,
//     this.maxLines = 1, this.keyboardType = TextInputType.text,
//     this.inputFormatters, this.onChanged, this.validator,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 14),
//       child: TextFormField(
//         controller: controller,
//         maxLines: maxLines,
//         keyboardType: keyboardType,
//         inputFormatters: inputFormatters,
//         onChanged: onChanged,
//         validator: validator,
//         style: AppTheme.bodyLarge.copyWith(color: Colors.black87), // ← FIX: explicit dark text
//         decoration: InputDecoration(
//           filled: true,                   // ← FIX: force fill
//           fillColor: Colors.white,        // ← FIX: explicit white fill
//           labelText: label,
//           hintText: hint,
//           hintStyle: AppTheme.bodySmall.copyWith(color: Colors.black38),
//           labelStyle: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
//           prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//             borderSide: const BorderSide(color: _C.border),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//             borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
//           ),
//           errorBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//             borderSide: BorderSide(color: AppTheme.criticalRed),
//           ),
//           focusedErrorBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//             borderSide: BorderSide(color: AppTheme.criticalRed, width: 1.5),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// /// Dropdown — explicitly white filled
// class _DropField<T> extends StatelessWidget {
//   final String                    label;
//   final IconData                  icon;
//   final T?                        value;
//   final List<DropdownMenuItem<T>> items;
//   final ValueChanged<T?>          onChanged;
//   final FormFieldValidator<T>?    validator;
//
//   const _DropField({
//     required this.label,    required this.icon,
//     required this.value,    required this.items,
//     required this.onChanged, this.validator,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 14),
//       child: DropdownButtonFormField<T>(
//         value: value, items: items, onChanged: onChanged, validator: validator,
//         style: AppTheme.bodyLarge.copyWith(color: Colors.black87), // ← FIX: explicit dark text
//         dropdownColor: Colors.white,                                // ← FIX: white dropdown panel
//         isExpanded: true,
//         icon: const Icon(Icons.expand_more, color: AppTheme.textSecondary),
//         decoration: InputDecoration(
//           filled: true,                   // ← FIX: force fill
//           fillColor: Colors.white,        // ← FIX: explicit white fill
//           labelText: label,
//           labelStyle: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
//           prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//             borderSide: const BorderSide(color: _C.border),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//             borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
//           ),
//           errorBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//             borderSide: BorderSide(color: AppTheme.criticalRed),
//           ),
//           focusedErrorBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//             borderSide: BorderSide(color: AppTheme.criticalRed, width: 1.5),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// /// Tappable date picker row
// class _DateField extends StatelessWidget {
//   final String    label;
//   final String    icon_unused;
//   final IconData  icon;
//   final String?   displayText;
//   final bool      hasValue;
//   final VoidCallback onPick;
//
//   const _DateField({
//     required this.label,       required this.icon,
//     required this.displayText, required this.hasValue,
//     required this.onPick,
//   }) : icon_unused = '';
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 14),
//       child: InkWell(
//         onTap: onPick,
//         borderRadius: BorderRadius.circular(10),
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
//           decoration: BoxDecoration(
//             color: Colors.white,  // ← FIX: explicit white
//             borderRadius: BorderRadius.circular(10),
//             border: Border.all(
//               color: hasValue ? AppTheme.primaryGreen : _C.border, // ← FIX: grey border when empty
//               width: hasValue ? 1.5 : 1,
//             ),
//           ),
//           child: Row(children: [
//             Icon(icon, size: 20, color: AppTheme.textSecondary),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Text(
//                 displayText ?? label,
//                 style: AppTheme.bodyLarge.copyWith(
//                   color: hasValue ? Colors.black87 : Colors.black38, // ← FIX: proper contrast
//                 ),
//               ),
//             ),
//             const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
//           ]),
//         ),
//       ),
//     );
//   }
// }
//
// /// Info / warning banner
// class _Banner extends StatelessWidget {
//   final String text;
//   final bool   isWarning;
//   const _Banner({required this.text, this.isWarning = false});
//
//   @override
//   Widget build(BuildContext context) {
//     final color = isWarning ? _C.warningText  : AppTheme.primaryGreen;
//     final bg    = isWarning ? _C.warningBg    : _C.infoBg;
//     return Container(
//       margin: const EdgeInsets.only(bottom: 16),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: bg, borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: color.withOpacity(0.35)),
//       ),
//       child: Text(text, style: AppTheme.bodySmall.copyWith(color: color, height: 1.5)),
//     );
//   }
// }
//
// /// Document upload card
// class _DocCard extends StatelessWidget {
//   final String    label, subtitle;
//   final IconData  icon;
//   final bool      isRequired, isUploaded;
//   final int       uploadedCount;
//   final VoidCallback onTap;
//   final Widget?   preview;
//
//   const _DocCard({
//     required this.label,       required this.subtitle,
//     required this.icon,        required this.isRequired,
//     required this.isUploaded,  required this.uploadedCount,
//     required this.onTap,       this.preview,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final borderColor = isUploaded
//         ? AppTheme.primaryGreen
//         : isRequired ? AppTheme.criticalRed.withOpacity(0.4) : _C.border;
//
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,  // ← FIX: explicit white card
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: borderColor, width: isUploaded ? 1.5 : 1),
//       ),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Padding(
//           padding: const EdgeInsets.all(14),
//           child: Row(children: [
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: isUploaded ? AppTheme.lightGreen : const Color(0xFFF5F5F5), // ← FIX: light grey instead of white-on-white
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Icon(
//                 isUploaded ? Icons.check : icon, size: 20,
//                 color: isUploaded ? AppTheme.primaryGreen : AppTheme.textSecondary,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                 Row(children: [
//                   Expanded(
//                     child: Text(label, style: AppTheme.bodyLarge.copyWith(
//                         fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)), // ← FIX
//                   ),
//                   if (isRequired)
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
//                       decoration: BoxDecoration(
//                         color: isUploaded
//                             ? AppTheme.lightGreen
//                             : AppTheme.criticalRed.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: Text(
//                         isUploaded ? 'Done' : 'Required',
//                         style: TextStyle(
//                           fontSize: 10, fontWeight: FontWeight.w700,
//                           color: isUploaded ? AppTheme.primaryGreen : AppTheme.criticalRed,
//                         ),
//                       ),
//                     ),
//                 ]),
//                 const SizedBox(height: 2),
//                 Text(subtitle, style: AppTheme.bodySmall.copyWith(fontSize: 12)),
//               ]),
//             ),
//           ]),
//         ),
//         if (preview != null) ...[
//           const Divider(height: 1),
//           Padding(padding: const EdgeInsets.all(12), child: preview),
//         ],
//         const Divider(height: 1),
//         InkWell(
//           onTap: onTap,
//           borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
//           child: Padding(
//             padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
//             child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
//               Icon(isUploaded ? Icons.refresh : Icons.upload_file,
//                   size: 16, color: AppTheme.primaryGreen),
//               const SizedBox(width: 6),
//               Text(
//                 isUploaded ? 'Replace / Add More' : 'Tap to Upload',
//                 style: AppTheme.bodySmall.copyWith(
//                     color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
//               ),
//             ]),
//           ),
//         ),
//       ]),
//     );
//   }
// }
//
// class _ImgPreview extends StatelessWidget {
//   final File file;
//   const _ImgPreview({required this.file});
//   @override
//   Widget build(BuildContext context) => ClipRRect(
//     borderRadius: BorderRadius.circular(8),
//     child: Image.file(file, height: 120, width: double.infinity, fit: BoxFit.cover),
//   );
// }
//
// class _MultiImgPreview extends StatelessWidget {
//   final List<File> files;
//   final ValueChanged<int> onRemove;
//   const _MultiImgPreview({required this.files, required this.onRemove});
//
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 80,
//       child: ListView.separated(
//         scrollDirection: Axis.horizontal,
//         itemCount: files.length,
//         separatorBuilder: (_, __) => const SizedBox(width: 8),
//         itemBuilder: (_, i) => Stack(children: [
//           ClipRRect(
//             borderRadius: BorderRadius.circular(8),
//             child: Image.file(files[i], width: 80, height: 80, fit: BoxFit.cover),
//           ),
//           Positioned(top: 2, right: 2,
//             child: GestureDetector(
//               onTap: () => onRemove(i),
//               child: Container(
//                 padding: const EdgeInsets.all(2),
//                 decoration: const BoxDecoration(color: AppTheme.criticalRed, shape: BoxShape.circle),
//                 child: const Icon(Icons.close, size: 12, color: Colors.white),
//               ),
//             ),
//           ),
//         ]),
//       ),
//     );
//   }
// }
//
// class _FileNamePreview extends StatelessWidget {
//   final File file;
//   const _FileNamePreview({required this.file});
//   @override
//   Widget build(BuildContext context) {
//     final name = file.path.split('/').last;
//     return Row(children: [
//       const Icon(Icons.insert_drive_file, color: AppTheme.primaryGreen, size: 20),
//       const SizedBox(width: 8),
//       Expanded(child: Text(name, style: AppTheme.bodySmall, overflow: TextOverflow.ellipsis)),
//       const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 18),
//     ]);
//   }
// }
//
// class _MultiFilePreview extends StatelessWidget {
//   final List<File>     files;
//   final ValueChanged<int> onRemove;
//   const _MultiFilePreview({required this.files, required this.onRemove});
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: List.generate(files.length, (i) {
//         final name = files[i].path.split('/').last;
//         return Padding(
//           padding: const EdgeInsets.only(bottom: 6),
//           child: Row(children: [
//             const Icon(Icons.attach_file, color: AppTheme.textSecondary, size: 16),
//             const SizedBox(width: 6),
//             Expanded(child: Text(name, style: AppTheme.bodySmall, overflow: TextOverflow.ellipsis)),
//             GestureDetector(
//               onTap: () => onRemove(i),
//               child: const Icon(Icons.cancel_outlined, color: AppTheme.criticalRed, size: 18),
//             ),
//           ]),
//         );
//       }),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────
// //  REVIEW CARD & ROW
// // ─────────────────────────────────────────────────────────────
// class _ReviewCard extends StatelessWidget {
//   final String        title;
//   final int           stepIndex;
//   final ValueChanged<int> onEdit;
//   final List<_RRow>   rows;
//
//   const _ReviewCard({
//     required this.title, required this.stepIndex,
//     required this.onEdit, required this.rows,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,  // ← FIX: explicit white card
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: _C.border),
//       ),
//       child: Column(children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
//           child: Row(children: [
//             Text(title, style: AppTheme.subHeading.copyWith(fontSize: 15, color: Colors.black87)), // ← FIX
//             const Spacer(),
//             TextButton.icon(
//               onPressed: () => onEdit(stepIndex),
//               icon: const Icon(Icons.edit_outlined, size: 14),
//               label: const Text('Edit', style: TextStyle(fontSize: 13)),
//               style: TextButton.styleFrom(
//                 foregroundColor: AppTheme.primaryGreen,
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//               ),
//             ),
//           ]),
//         ),
//         const Divider(height: 1),
//         Padding(padding: const EdgeInsets.all(16), child: Column(children: rows)),
//       ]),
//     );
//   }
// }
//
// class _RRow extends StatelessWidget {
//   final String label, value;
//   final bool?  positive;
//   const _RRow(this.label, this.value, {this.positive});
//
//   @override
//   Widget build(BuildContext context) {
//     final Color col = positive == true
//         ? AppTheme.primaryGreen
//         : positive == false
//         ? AppTheme.criticalRed
//         : Colors.black87; // ← FIX: explicit dark instead of AppTheme.textPrimary which may be light
//
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 10),
//       child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         SizedBox(width: 130, child: Text(label, style: AppTheme.bodySmall.copyWith(color: Colors.black54))), // ← FIX
//         Expanded(
//           child: Text(
//             value.isEmpty ? '—' : value,
//             style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600, color: col),
//           ),
//         ),
//       ]),
//     );
//   }
// }