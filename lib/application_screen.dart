import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mukammalpakistanparty/%20config/app_theme.dart';
import 'package:file_picker/file_picker.dart';
class ApplicationScreen extends StatefulWidget {
  const ApplicationScreen({super.key});

  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final User? _user = FirebaseAuth.instance.currentUser;

  // ── Controllers ──────────────────────────────────────────────────────
  final _nameController            = TextEditingController();
  final _emailController           = TextEditingController();
  final _phoneController           = TextEditingController();
  final _cnicController            = TextEditingController();
  final _addressController         = TextEditingController();
  final _qualificationController   = TextEditingController();
  final _experienceController      = TextEditingController();
  final _descriptionController     = TextEditingController();
  final _skillsController          = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────
  String?       _selectedRole;
  String?       _selectedEducation;
  File?         _idCardFile;
  File?         _certificateFile;
  File?         _profilePicFile;
  final List<File> _otherDocs = [];

  // ── Roles from Firestore ──────────────────────────────────────────────
  List<String>  _roles      = [];
  bool          _rolesLoading = true;

  bool _isLoading      = false;
  bool _alreadyApplied = false;

  // ── Education Options ─────────────────────────────────────────────────
  final List<String> _educationLevels = [
    'Matric',
    'Intermediate',
    'Bachelor\'s',
    'Master\'s',
    'M.Phil',
    'PhD',
    'Other',
  ];

  // ─────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _prefillUserData();
    _checkExistingApplication();
    _fetchRoles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cnicController.dispose();
    _addressController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    _descriptionController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  // ── Fetch Roles from Firestore ────────────────────────────────────────
  Future<void> _fetchRoles() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('roles')
          .get();

      final fetchedRoles = snapshot.docs
          .map((doc) => doc.id) // document ID = role name
          .toList();

      setState(() {
        _roles       = fetchedRoles;
        _rolesLoading = false;
      });
    } catch (e) {
      setState(() => _rolesLoading = false);
      _showSnack("Failed to load roles: $e");
    }
  }

  // ── Pre-fill from Firestore ───────────────────────────────────────────
  Future<void> _prefillUserData() async {
    if (_user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .get();
    final data = doc.data();
    if (data == null) return;
    setState(() {
      _nameController.text  = data['name']  ?? '';
      _emailController.text = data['email'] ?? '';
      _phoneController.text = data['phone'] ?? '';
    });
  }

  // ── Already Applied? ──────────────────────────────────────────────────
  Future<void> _checkExistingApplication() async {
    if (_user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('membership_applications')
        .where('user_id', isEqualTo: _user!.uid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (snap.docs.isNotEmpty) {
      setState(() => _alreadyApplied = true);
    }
  }

  // ── File Pickers ──────────────────────────────────────────────────────
  Future<void> _pickIdCard() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null) {
      setState(() => _idCardFile = File(result.files.single.path!));
    }
  }

  Future<void> _pickCertificate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null) {
      setState(() => _certificateFile = File(result.files.single.path!));
    }
  }

  Future<void> _pickProfilePic() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _profilePicFile = File(picked.path));
    }
  }

  Future<void> _pickOtherDoc() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );
    if (result != null) {
      setState(() => _otherDocs.add(File(result.files.single.path!)));
    }
  }

  void _removeOtherDoc(int index) {
    setState(() => _otherDocs.removeAt(index));
  }

  // ── Upload Helper ─────────────────────────────────────────────────────
  Future<String?> _uploadFile(File file, String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  // ── Submit ────────────────────────────────────────────────────────────
  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == null) {
      _showSnack("Please select a role to apply for.");
      return;
    }
    if (_idCardFile == null) {
      _showSnack("Please upload your CNIC / ID Card.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = _user!.uid;

      // Upload profile picture
      String? profileUrl;
      if (_profilePicFile != null) {
        profileUrl = await _uploadFile(
          _profilePicFile!,
          'users/$uid/profile_picture/profile.jpg',
        );
      }

      // Upload ID card
      final idCardUrl = await _uploadFile(
        _idCardFile!,
        'users/$uid/documents/id_card.${_idCardFile!.path.split('.').last}',
      );

      // Upload certificate
      String? certUrl;
      if (_certificateFile != null) {
        certUrl = await _uploadFile(
          _certificateFile!,
          'users/$uid/documents/certificate.${_certificateFile!.path.split('.').last}',
        );
      }

      // Upload other docs
      final List<String> otherUrls = [];
      for (int i = 0; i < _otherDocs.length; i++) {
        final url = await _uploadFile(
          _otherDocs[i],
          'users/$uid/documents/other_$i.${_otherDocs[i].path.split('.').last}',
        );
        if (url != null) otherUrls.add(url);
      }

      // Save application to Firestore
      await FirebaseFirestore.instance
          .collection('membership_applications')
          .add({
        'user_id':       uid,
        'name':          _nameController.text.trim(),
        'email':         _emailController.text.trim(),
        'phone':         _phoneController.text.trim(),
        'cnic':          _cnicController.text.trim(),
        'address':       _addressController.text.trim(),
        'education':     _selectedEducation,
        'qualification': _qualificationController.text.trim(),
        'experience':    _experienceController.text.trim(),
        'skills':        _skillsController.text.trim(),
        'post':          _selectedRole,
        'description':   _descriptionController.text.trim(),
        'documents': {
          'id_card':     idCardUrl,
          'certificate': certUrl,
          'other':       otherUrls,
        },
        'profile_picture': profileUrl,
        'status':        'pending',
        'submitted_at':  FieldValue.serverTimestamp(),
        'reviewed_at':   null,
        'reviewed_by':   null,
      });

      // Update user profile picture
      if (profileUrl != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'profile_picture': profileUrl});
      }

      // Update membership status
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'membership_status': 'pending'});

      setState(() => _alreadyApplied = true);
      _showSnack("Application submitted successfully! ✅");
      Navigator.pop(context);
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_alreadyApplied) return _buildAlreadyApplied();

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text("Membership Application"),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Profile Picture ──────────────────────────────
              _buildSectionHeader(
                icon: Icons.camera_alt,
                title: "Profile Picture",
              ),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: _pickProfilePic,
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor:
                    AppTheme.primaryGreen.withOpacity(0.1),
                    backgroundImage: _profilePicFile != null
                        ? FileImage(_profilePicFile!)
                        : null,
                    child: _profilePicFile == null
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_a_photo,
                            color: AppTheme.primaryGreen,
                            size: 28),
                        SizedBox(height: 4),
                        Text("Upload",
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryGreen)),
                      ],
                    )
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Personal Information ─────────────────────────
              _buildSectionHeader(
                icon: Icons.person_outline,
                title: "Personal Information",
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _nameController,
                label: "Full Name",
                hint: "Enter your full name",
                icon: Icons.badge_outlined,
                validator: (v) =>
                v!.isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _emailController,
                label: "Email Address",
                hint: "Enter your email",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                v!.isEmpty ? "Email is required" : null,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _phoneController,
                label: "Phone Number",
                hint: "03XX-XXXXXXX",
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                v!.isEmpty ? "Phone is required" : null,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _cnicController,
                label: "CNIC Number",
                hint: "XXXXX-XXXXXXX-X",
                icon: Icons.credit_card_outlined,
                keyboardType: TextInputType.number,
                validator: (v) =>
                v!.isEmpty ? "CNIC is required" : null,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _addressController,
                label: "Full Address",
                hint: "City, District, Province",
                icon: Icons.location_on_outlined,
                maxLines: 2,
                validator: (v) =>
                v!.isEmpty ? "Address is required" : null,
              ),

              const SizedBox(height: 24),

              // ── Role Selection ───────────────────────────────
              _buildSectionHeader(
                icon: Icons.work_outline,
                title: "Role You Are Applying For",
              ),
              const SizedBox(height: 12),

              _rolesLoading
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
                  : _roles.isEmpty
                  ? Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.orange.shade200),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange),
                    SizedBox(width: 10),
                    Text("No roles available right now.",
                        style:
                        TextStyle(color: Colors.orange)),
                  ],
                ),
              )
                  : Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("Select Role"),
                    value: _selectedRole,
                    icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppTheme.primaryGreen),
                    items: _roles.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(
                          // Capitalize first letter of each word
                          role
                              .split(' ')
                              .map((w) => w.isNotEmpty
                              ? '${w[0].toUpperCase()}${w.substring(1)}'
                              : w)
                              .join(' '),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedRole = val),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Education & Qualifications ───────────────────
              _buildSectionHeader(
                icon: Icons.school_outlined,
                title: "Education & Qualifications",
              ),
              const SizedBox(height: 12),

              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                  Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint:
                    const Text("Highest Education Level"),
                    value: _selectedEducation,
                    icon: const Icon(Icons.arrow_drop_down,
                        color: AppTheme.primaryGreen),
                    items: _educationLevels.map((edu) {
                      return DropdownMenuItem(
                        value: edu,
                        child: Text(edu),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedEducation = val),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _qualificationController,
                label: "Degree / Qualification Details",
                hint: "e.g., BS Computer Science from FAST",
                icon: Icons.menu_book_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _experienceController,
                label: "Work / Political Experience",
                hint: "Briefly describe your experience",
                icon: Icons.history_edu_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _skillsController,
                label: "Skills",
                hint: "e.g., Public Speaking, Leadership, IT",
                icon: Icons.star_outline,
              ),

              const SizedBox(height: 24),

              // ── Why Join ─────────────────────────────────────
              _buildSectionHeader(
                icon: Icons.article_outlined,
                title: "Why Do You Want to Join?",
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _descriptionController,
                label: "Personal Statement",
                hint:
                "Describe your motivation for joining Mukamal Pakistan Party, your goals and how you plan to contribute...",
                icon: Icons.edit_note_outlined,
                maxLines: 6,
                validator: (v) => v!.trim().length < 20
                    ? "Please write at least 20 characters"
                    : null,
              ),

              const SizedBox(height: 24),

              // ── Documents ────────────────────────────────────
              _buildSectionHeader(
                icon: Icons.folder_outlined,
                title: "Documents & Certificates",
              ),
              const SizedBox(height: 12),

              _buildDocTile(
                label: "CNIC / ID Card *",
                subtitle: _idCardFile != null
                    ? _idCardFile!.path.split('/').last
                    : "Upload JPG, PNG or PDF",
                icon: Icons.credit_card,
                uploaded: _idCardFile != null,
                onTap: _pickIdCard,
              ),
              const SizedBox(height: 10),

              _buildDocTile(
                label: "Degree / Certificate",
                subtitle: _certificateFile != null
                    ? _certificateFile!.path.split('/').last
                    : "Upload JPG, PNG or PDF",
                icon: Icons.workspace_premium_outlined,
                uploaded: _certificateFile != null,
                onTap: _pickCertificate,
              ),
              const SizedBox(height: 10),

              if (_otherDocs.isNotEmpty)
                ..._otherDocs.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildDocTile(
                      label:
                      "Additional Document ${entry.key + 1}",
                      subtitle:
                      entry.value.path.split('/').last,
                      icon: Icons.attach_file,
                      uploaded: true,
                      onTap: () {},
                      trailing: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.red),
                        onPressed: () =>
                            _removeOtherDoc(entry.key),
                      ),
                    ),
                  );
                }),

              TextButton.icon(
                onPressed: _pickOtherDoc,
                icon: const Icon(Icons.add,
                    color: AppTheme.primaryGreen),
                label: const Text(
                  "Add Another Document",
                  style: TextStyle(color: AppTheme.primaryGreen),
                ),
              ),

              const SizedBox(height: 30),

              // ── Submit ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: AppTheme.primaryButton,
                  onPressed: _submitApplication,
                  icon: const Icon(Icons.send),
                  label: const Text(
                    "Submit Application",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── Already Applied Screen ────────────────────────────────────────────
  Widget _buildAlreadyApplied() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text("Membership Application"),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top_rounded,
                  size: 80,
                  color: AppTheme.primaryGreen.withOpacity(0.8)),
              const SizedBox(height: 20),
              const Text(
                "Application Submitted!",
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "Your membership application is under review.\nYou will be notified once it is approved.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: AppTheme.primaryButton,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text("Back to Home"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reusable Widgets ──────────────────────────────────────────────────
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppTheme.subHeading),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppTheme.primaryGreen, width: 2),
        ),
      ),
    );
  }

  Widget _buildDocTile({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool uploaded,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: uploaded
                ? AppTheme.primaryGreen
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: uploaded
                    ? AppTheme.primaryGreen.withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: uploaded
                    ? AppTheme.primaryGreen
                    : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            trailing ??
                Icon(
                  uploaded
                      ? Icons.check_circle
                      : Icons.upload_file,
                  color: uploaded
                      ? AppTheme.primaryGreen
                      : Colors.grey,
                ),
          ],
        ),
      ),
    );
  }
}