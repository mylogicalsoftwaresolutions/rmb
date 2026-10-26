import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/member_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';
import '../widgets/image_viewer.dart';

class MyProfileScreen extends StatefulWidget {
  final Map<String, String> user;

  const MyProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  String _selectedTab = 'Personal';

  bool _isLoading = true;
  bool _isUpdating = false;

  String? _errorMessage;

  String _profileName = '';
  String _profileChapter = '';
  String _profileMobile = '';
  String _profileEmail = '';
  String _profileRole = '';
  String _profileCompany = '';
  String _profileAvatar = '';

  // Personal
  final TextEditingController _firstNameController =
  TextEditingController();
  final TextEditingController _lastNameController =
  TextEditingController();
  final TextEditingController _displayNameController =
  TextEditingController();
  final TextEditingController _emailController =
  TextEditingController();
  final TextEditingController _dobController =
  TextEditingController();
  final TextEditingController _genderController =
  TextEditingController();
  final TextEditingController _bloodGroupController =
  TextEditingController();

  // Business
  final TextEditingController _companyController =
  TextEditingController();
  final TextEditingController _classificationController =
  TextEditingController();
  final TextEditingController _experienceController =
  TextEditingController();
  final TextEditingController _productsController =
  TextEditingController();
  final TextEditingController _gstNumberController =
  TextEditingController();
  final TextEditingController _websiteController =
  TextEditingController();

  // Social links
  final TextEditingController _linkedinController =
  TextEditingController();
  final TextEditingController _facebookController =
  TextEditingController();
  final TextEditingController _instagramController =
  TextEditingController();
  final TextEditingController _twitterController =
  TextEditingController();

  // Family
  final TextEditingController _spouseNameController =
  TextEditingController();
  final TextEditingController _anniversaryController =
  TextEditingController();

  // Residential address
  final TextEditingController _address1Controller =
  TextEditingController();
  final TextEditingController _cityController =
  TextEditingController();
  final TextEditingController _stateController =
  TextEditingController();
  final TextEditingController _pincodeController =
  TextEditingController();

  // Office address
  final TextEditingController _officeAddressController =
  TextEditingController();
  final TextEditingController _officeCityController =
  TextEditingController();
  final TextEditingController _officeStateController =
  TextEditingController();
  final TextEditingController _officePincodeController =
  TextEditingController();

  // KYC
  final TextEditingController _aadharNumberController =
  TextEditingController();
  final TextEditingController _panNumberController =
  TextEditingController();

  String? _selectedProfilePhoto;
  Uint8List? _selectedProfileBytes;
  String? _selectedAadharPhoto;
  String? _selectedPanPhoto;
  String? _selectedGstPhoto;
  String? _selectedVisitingPhoto;

  @override
  void initState() {
    super.initState();
    _initFromUser(widget.user);
    _loadAddressFallback();
    _fetchProfile();
  }

  String _formatDateForDisplay(dynamic rawDate) {
    if (rawDate == null) return '';
    final str = rawDate.toString().trim();
    if (str.isEmpty || str == '0000-00-00' || str == 'null' || str == '—') return '';

    // Check if it's already DD-MM-YYYY or D-M-YYYY
    final ddmmyyyyRegex = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})');
    if (ddmmyyyyRegex.hasMatch(str)) {
      final match = ddmmyyyyRegex.firstMatch(str)!;
      final d = match.group(1)!.padLeft(2, '0');
      final m = match.group(2)!.padLeft(2, '0');
      final y = match.group(3)!;
      return '$d-$m-$y';
    }

    // Check if it's YYYY-MM-DD
    final yyyymmddRegex = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})');
    if (yyyymmddRegex.hasMatch(str)) {
      final match = yyyymmddRegex.firstMatch(str)!;
      final y = match.group(1)!;
      final m = match.group(2)!.padLeft(2, '0');
      final d = match.group(3)!.padLeft(2, '0');
      return '$d-$m-$y';
    }

    try {
      final parsed = DateTime.parse(str);
      return '${parsed.day.toString().padLeft(2, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.year}';
    } catch (_) {
      return str;
    }
  }

  String _formatDateForApi(String ddmmyyyy) {
    final trimmed = ddmmyyyy.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'[-/]'));
    if (parts.length == 3 && parts[0].length <= 2 && parts[2].length == 4) {
      // DD-MM-YYYY -> YYYY-MM-DD
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }
    return trimmed;
  }

  Future<void> _loadAddressFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final a1 = prefs.getString('user_address_1') ?? prefs.getString('user_address') ?? '';
      final c = prefs.getString('user_city') ?? '';
      final s = prefs.getString('user_state') ?? '';
      final p = prefs.getString('user_pincode') ?? prefs.getString('user_pin') ?? '';
      final cachedDob = prefs.getString('user_dob') ?? prefs.getString('user_birthday') ?? '';
      final cachedAnn = prefs.getString('user_anniversary') ?? prefs.getString('user_anniversary_date') ?? '';

      if (a1.isNotEmpty && _address1Controller.text.isEmpty) _address1Controller.text = a1;
      if (c.isNotEmpty && _cityController.text.isEmpty) _cityController.text = c;
      if (s.isNotEmpty && _stateController.text.isEmpty) _stateController.text = s;
      if (p.isNotEmpty && _pincodeController.text.isEmpty) _pincodeController.text = p;
      if (cachedDob.isNotEmpty && _dobController.text.isEmpty) {
        _dobController.text = _formatDateForDisplay(cachedDob);
      }
      if (cachedAnn.isNotEmpty && _anniversaryController.text.isEmpty) {
        _anniversaryController.text = _formatDateForDisplay(cachedAnn);
      }

      if (_cityController.text.isEmpty || _address1Controller.text.isEmpty || _dobController.text.isEmpty || _anniversaryController.text.isEmpty) {
        final members = await MemberService.getAllMembers();
        final userId = prefs.getString('user_id') ?? '';
        final userMobile = prefs.getString('login_username') ?? '';
        for (final m in members) {
          if ((userId.isNotEmpty && m.id.toString() == userId) ||
              (userMobile.isNotEmpty && m.mobile == userMobile)) {
            if (_cityController.text.isEmpty && m.city.isNotEmpty) {
              _cityController.text = m.city;
            }
            if (_address1Controller.text.isEmpty && m.rawJson != null) {
              final rawAddr = m.rawJson!['address'] ??
                  m.rawJson!['address_line_1'] ??
                  m.rawJson!['address_1'] ??
                  m.rawJson!['address1'] ??
                  m.rawJson!['street'] ??
                  m.rawJson!['street_address'] ??
                  m.rawJson!['location'] ??
                  m.rawJson!['office_address'] ??
                  m.rawJson!['company_address'] ??
                  m.rawJson!['business_address'];
              if (rawAddr != null && rawAddr.toString().trim().isNotEmpty) {
                _address1Controller.text = rawAddr.toString().trim();
              }
            }
            if (_stateController.text.isEmpty && m.rawJson != null) {
              final rawState = m.rawJson!['state'] ?? m.rawJson!['region'];
              if (rawState != null && rawState.toString().trim().isNotEmpty) {
                _stateController.text = rawState.toString().trim();
              }
            }
            if (_pincodeController.text.isEmpty && m.rawJson != null) {
              final rawPin = m.rawJson!['pincode'] ??
                  m.rawJson!['pin_code'] ??
                  m.rawJson!['zip'] ??
                  m.rawJson!['postal_code'];
              if (rawPin != null && rawPin.toString().trim().isNotEmpty) {
                _pincodeController.text = rawPin.toString().trim();
              }
            }
            if (_dobController.text.isEmpty && m.rawJson != null) {
              final rawDob = m.rawJson!['dob'] ?? m.rawJson!['birth_date'] ?? m.rawJson!['birthday'] ?? m.rawJson!['date_of_birth'];
              if (rawDob != null && rawDob.toString().trim() != '0000-00-00') {
                _dobController.text = _formatDateForDisplay(rawDob);
              }
            }
            if (_anniversaryController.text.isEmpty && m.rawJson != null) {
              final rawAnn = m.rawJson!['anniversary'] ?? m.rawJson!['anniversary_date'] ?? m.rawJson!['wedding_anniversary'];
              if (rawAnn != null && rawAnn.toString().trim() != '0000-00-00') {
                _anniversaryController.text = _formatDateForDisplay(rawAnn);
              }
            }
            break;
          }
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _initFromUser(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    _profileName = (data['name'] ?? data['display_name'] ?? data['first_name'] ?? _profileName).toString();
    _profileMobile = (data['mobile'] ?? data['phone'] ?? _profileMobile).toString();
    _profileEmail = (data['email'] ?? _profileEmail).toString();
    _profileChapter = (data['chapter_name'] ?? data['chapter'] ?? _profileChapter).toString();
    _profileRole = (data['role_name'] ?? data['role'] ?? _profileRole).toString();
    _profileCompany = (data['company_name'] ?? data['company'] ?? _profileCompany).toString();
    _profileAvatar = (data['avatar'] ?? data['profile_photo'] ?? _profileAvatar).toString();

    if (_firstNameController.text.isEmpty && (data['first_name'] != null || _profileName.isNotEmpty)) {
      _firstNameController.text = (data['first_name'] ?? _profileName).toString();
    }
    if (_lastNameController.text.isEmpty && data['last_name'] != null) {
      _lastNameController.text = data['last_name'].toString();
    }
    if (_displayNameController.text.isEmpty && (data['display_name'] != null || _profileName.isNotEmpty)) {
      _displayNameController.text = (data['display_name'] ?? _profileName).toString();
    }
    if (_emailController.text.isEmpty && _profileEmail.isNotEmpty) {
      _emailController.text = _profileEmail;
    }
    final rawDob = data['dob'] ??
        data['birth_date'] ??
        data['birthday'] ??
        data['date_of_birth'] ??
        data['birthdate'];
    if (_dobController.text.isEmpty && rawDob != null && rawDob.toString().trim() != '0000-00-00') {
      _dobController.text = _formatDateForDisplay(rawDob);
    }
    if (_genderController.text.isEmpty && data['gender'] != null) {
      _genderController.text = data['gender'].toString();
    }
    if (_bloodGroupController.text.isEmpty && data['blood_group'] != null) {
      _bloodGroupController.text = data['blood_group'].toString();
    }

    if (_companyController.text.isEmpty && _profileCompany.isNotEmpty) {
      _companyController.text = _profileCompany;
    }
    if (_classificationController.text.isEmpty && (data['business_category'] != null || data['classification'] != null || data['category'] != null)) {
      _classificationController.text = (data['business_category'] ?? data['classification'] ?? data['category']).toString();
    }
    if (_experienceController.text.isEmpty && data['experience'] != null) {
      _experienceController.text = data['experience'].toString();
    }
    if (_productsController.text.isEmpty && (data['business_description'] != null || data['products'] != null || data['services'] != null)) {
      _productsController.text = (data['business_description'] ?? data['products'] ?? data['services']).toString();
    }
    if (_gstNumberController.text.isEmpty && (data['gst_number'] != null || data['gst'] != null)) {
      _gstNumberController.text = (data['gst_number'] ?? data['gst']).toString();
    }
    if (_websiteController.text.isEmpty && data['website'] != null) {
      _websiteController.text = data['website'].toString();
    }
    if (_linkedinController.text.isEmpty && data['linkedin'] != null) {
      _linkedinController.text = data['linkedin'].toString();
    }
    if (_facebookController.text.isEmpty && data['facebook'] != null) {
      _facebookController.text = data['facebook'].toString();
    }
    if (_instagramController.text.isEmpty && data['instagram'] != null) {
      _instagramController.text = data['instagram'].toString();
    }
    if (_twitterController.text.isEmpty && data['twitter'] != null) {
      _twitterController.text = data['twitter'].toString();
    }

    if (_spouseNameController.text.isEmpty && data['spouse_name'] != null) {
      _spouseNameController.text = data['spouse_name'].toString();
    }
    final rawAnniversary = data['anniversary'] ??
        data['anniversary_date'] ??
        data['wedding_anniversary'] ??
        data['anniversary_day'];
    if (_anniversaryController.text.isEmpty && rawAnniversary != null && rawAnniversary.toString().trim() != '0000-00-00') {
      _anniversaryController.text = _formatDateForDisplay(rawAnniversary);
    }

    Map<String, dynamic> addrMap = {};
    String addrStr = '';
    if (data['address'] is Map) {
      addrMap = Map<String, dynamic>.from(data['address'] as Map);
    } else if (data['address'] is List && (data['address'] as List).isNotEmpty && (data['address'] as List).first is Map) {
      addrMap = Map<String, dynamic>.from((data['address'] as List).first as Map);
    } else if (data['address'] != null && data['address'] is! Map && data['address'] is! List) {
      addrStr = data['address'].toString().trim();
    }

    final rawAddr1 = data['address_line_1'] ??
        data['address'] ??
        data['address_1'] ??
        data['address1'] ??
        data['line1'] ??
        data['street'] ??
        data['street_address'] ??
        data['office_address'] ??
        data['company_address'] ??
        data['business_address'] ??
        data['location'] ??
        addrMap['address_line_1'] ??
        addrMap['address'] ??
        addrMap['address_1'] ??
        addrMap['address1'] ??
        addrMap['line1'] ??
        addrMap['street'] ??
        (addrStr.isNotEmpty ? addrStr : null);
    if (_address1Controller.text.isEmpty && rawAddr1 != null && rawAddr1.toString().isNotEmpty) {
      _address1Controller.text = rawAddr1.toString();
    }
    final rawCity = data['city'] ?? data['residential_city'] ?? addrMap['city'];
    if (_cityController.text.isEmpty && rawCity != null && rawCity.toString().isNotEmpty) {
      _cityController.text = rawCity.toString();
    }
    final rawState = data['state'] ?? data['residential_state'] ?? addrMap['state'];
    if (_stateController.text.isEmpty && rawState != null && rawState.toString().isNotEmpty) {
      _stateController.text = rawState.toString();
    }
    final rawPin = data['pincode'] ??
        data['residential_pincode'] ??
        data['pin_code'] ??
        data['zip'] ??
        addrMap['pincode'] ??
        addrMap['pin_code'] ??
        addrMap['zip'];
    if (_pincodeController.text.isEmpty && rawPin != null && rawPin.toString().isNotEmpty) {
      _pincodeController.text = rawPin.toString();
    }

    // Office address
    final rawOfficeAddr = data['office_address'];
    if (_officeAddressController.text.isEmpty && rawOfficeAddr != null && rawOfficeAddr.toString().isNotEmpty) {
      _officeAddressController.text = rawOfficeAddr.toString();
    }
    if (_officeCityController.text.isEmpty && data['office_city'] != null) {
      _officeCityController.text = data['office_city'].toString();
    }
    if (_officeStateController.text.isEmpty && data['office_state'] != null) {
      _officeStateController.text = data['office_state'].toString();
    }
    if (_officePincodeController.text.isEmpty && data['office_pincode'] != null) {
      _officePincodeController.text = data['office_pincode'].toString();
    }

    if (_aadharNumberController.text.isEmpty && (data['aadhar_number'] != null || data['aadhar'] != null)) {
      _aadharNumberController.text = (data['aadhar_number'] ?? data['aadhar']).toString();
    }
    if (_panNumberController.text.isEmpty && (data['pan_number'] != null || data['pan'] != null)) {
      _panNumberController.text = (data['pan_number'] ?? data['pan']).toString();
    }
  }

  String _formattedAddress() {
    final parts = [
      _address1Controller.text.trim(),
      _cityController.text.trim(),
      _stateController.text.trim(),
      _pincodeController.text.trim(),
    ].where((p) => p.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(', ') : 'Not provided';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _bloodGroupController.dispose();

    _companyController.dispose();
    _classificationController.dispose();
    _experienceController.dispose();
    _productsController.dispose();
    _gstNumberController.dispose();
    _websiteController.dispose();

    _linkedinController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();

    _spouseNameController.dispose();
    _anniversaryController.dispose();

    _address1Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();

    _officeAddressController.dispose();
    _officeCityController.dispose();
    _officeStateController.dispose();
    _officePincodeController.dispose();

    _aadharNumberController.dispose();
    _panNumberController.dispose();

    super.dispose();
  }

  Future<void> _pickFile(
    Function(String) onPicked, {
    Function(Uint8List, String)? onFilePicked,
  }) async {
    debugPrint('scan or click open');

    try {
      final files = await FilePicker.pickFiles(type: FileType.image);

      if (files.isNotEmpty && mounted) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          onPicked(file.name);
          onFilePicked?.call(bytes, file.name);
        });
      }
    } catch (e) {
      debugPrint('File picker error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to select file: ${e.toString()}',
          ),
        ),
      );
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await AuthService.getProfile();

      if (!mounted) return;

      setState(() {
        _initFromUser(data);

        if (data['first_name'] != null && data['first_name'].toString().isNotEmpty) {
          _firstNameController.text = data['first_name'].toString();
        }
        if (data['last_name'] != null && data['last_name'].toString().isNotEmpty) {
          _lastNameController.text = data['last_name'].toString();
        }
        if (data['display_name'] != null && data['display_name'].toString().isNotEmpty) {
          _displayNameController.text = data['display_name'].toString();
        }
        if (data['email'] != null && data['email'].toString().isNotEmpty) {
          _emailController.text = data['email'].toString();
        }
        final rawDob = data['dob'] ??
            data['birth_date'] ??
            data['birthday'] ??
            data['date_of_birth'] ??
            data['birthdate'] ??
            data['bday'] ??
            data['dob_date'] ??
            data['dateOfBirth'];
        if (rawDob != null && rawDob.toString().trim().isNotEmpty && rawDob.toString().trim() != '0000-00-00') {
          _dobController.text = _formatDateForDisplay(rawDob);
        }
        if (data['gender'] != null && data['gender'].toString().isNotEmpty) {
          _genderController.text = data['gender'].toString();
        }
        if (data['blood_group'] != null && data['blood_group'].toString().isNotEmpty) {
          _bloodGroupController.text = data['blood_group'].toString();
        }

        if (data['company_name'] != null || data['company'] != null) {
          _companyController.text = (data['company_name'] ?? data['company']).toString();
        }
        if (data['business_category'] != null || data['classification'] != null || data['category'] != null) {
          _classificationController.text = (data['business_category'] ?? data['classification'] ?? data['category']).toString();
        }
        if (data['experience'] != null && data['experience'].toString().isNotEmpty) {
          _experienceController.text = data['experience'].toString();
        }
        if (data['business_description'] != null || data['products'] != null || data['services'] != null) {
          _productsController.text = (data['business_description'] ?? data['products'] ?? data['services']).toString();
        }

        if (data['spouse_name'] != null && data['spouse_name'].toString().isNotEmpty) {
          _spouseNameController.text = data['spouse_name'].toString();
        }
        final rawAnn = data['anniversary'] ??
            data['anniversary_date'] ??
            data['wedding_anniversary'] ??
            data['anniversary_day'];
        if (rawAnn != null && rawAnn.toString().trim().isNotEmpty && rawAnn.toString().trim() != '0000-00-00') {
          _anniversaryController.text = _formatDateForDisplay(rawAnn);
        }

        Map<String, dynamic> fetchAddrMap = {};
        String fetchAddrStr = '';
        if (data['address'] is Map) {
          fetchAddrMap = Map<String, dynamic>.from(data['address'] as Map);
        } else if (data['address'] is List && (data['address'] as List).isNotEmpty && (data['address'] as List).first is Map) {
          fetchAddrMap = Map<String, dynamic>.from((data['address'] as List).first as Map);
        } else if (data['address'] != null && data['address'] is! Map && data['address'] is! List) {
          fetchAddrStr = data['address'].toString().trim();
        }

        final fetchAddr1 = data['address_line_1'] ??
            data['address'] ??
            data['address_1'] ??
            data['address1'] ??
            data['line1'] ??
            data['street'] ??
            data['street_address'] ??
            data['office_address'] ??
            data['company_address'] ??
            data['business_address'] ??
            data['location'] ??
            fetchAddrMap['address_line_1'] ??
            fetchAddrMap['address'] ??
            fetchAddrMap['address_1'] ??
            fetchAddrMap['address1'] ??
            fetchAddrMap['line1'] ??
            fetchAddrMap['street'] ??
            (fetchAddrStr.isNotEmpty ? fetchAddrStr : null);
        if (fetchAddr1 != null && fetchAddr1.toString().isNotEmpty) {
          _address1Controller.text = fetchAddr1.toString();
        }
        final fetchCity = data['city'] ?? fetchAddrMap['city'];
        if (fetchCity != null && fetchCity.toString().isNotEmpty) {
          _cityController.text = fetchCity.toString();
        }
        final fetchState = data['state'] ?? fetchAddrMap['state'];
        if (fetchState != null && fetchState.toString().isNotEmpty) {
          _stateController.text = fetchState.toString();
        }
        final fetchPin = data['pincode'] ??
            data['pin_code'] ??
            data['zip'] ??
            fetchAddrMap['pincode'] ??
            fetchAddrMap['pin_code'] ??
            fetchAddrMap['zip'];
        if (fetchPin != null && fetchPin.toString().isNotEmpty) {
          _pincodeController.text = fetchPin.toString();
        }

        if (_address1Controller.text.isEmpty && _cityController.text.isEmpty) {
          _loadAddressFallback();
        }

        // Office address
        if (data['office_address'] != null && data['office_address'].toString().isNotEmpty) {
          _officeAddressController.text = data['office_address'].toString();
        }
        if (data['office_city'] != null && data['office_city'].toString().isNotEmpty) {
          _officeCityController.text = data['office_city'].toString();
        }
        if (data['office_state'] != null && data['office_state'].toString().isNotEmpty) {
          _officeStateController.text = data['office_state'].toString();
        }
        if (data['office_pincode'] != null && data['office_pincode'].toString().isNotEmpty) {
          _officePincodeController.text = data['office_pincode'].toString();
        }

        // Business extras
        if (data['gst_number'] != null && data['gst_number'].toString().isNotEmpty) {
          _gstNumberController.text = data['gst_number'].toString();
        } else if (data['gst'] != null && data['gst'].toString().isNotEmpty) {
          _gstNumberController.text = data['gst'].toString();
        }
        if (data['website'] != null && data['website'].toString().isNotEmpty) {
          _websiteController.text = data['website'].toString();
        }

        // Social links
        if (data['linkedin'] != null && data['linkedin'].toString().isNotEmpty) {
          _linkedinController.text = data['linkedin'].toString();
        }
        if (data['facebook'] != null && data['facebook'].toString().isNotEmpty) {
          _facebookController.text = data['facebook'].toString();
        }
        if (data['instagram'] != null && data['instagram'].toString().isNotEmpty) {
          _instagramController.text = data['instagram'].toString();
        }
        if (data['twitter'] != null && data['twitter'].toString().isNotEmpty) {
          _twitterController.text = data['twitter'].toString();
        }

        if (data['aadhar_number'] != null || data['aadhar'] != null) {
          _aadharNumberController.text = (data['aadhar_number'] ?? data['aadhar']).toString();
        }
        if (data['pan_number'] != null || data['pan'] != null) {
          _panNumberController.text = (data['pan_number'] ?? data['pan']).toString();
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final apiDob = _formatDateForApi(_dobController.text);
      final apiAnniversary = _formatDateForApi(_anniversaryController.text);

      List<http.MultipartFile>? uploadFiles;
      if (_selectedProfileBytes != null && _selectedProfilePhoto != null) {
        uploadFiles = [
          http.MultipartFile.fromBytes(
            'profile_photo',
            _selectedProfileBytes!,
            filename: _selectedProfilePhoto!,
          ),
        ];
      }

      await AuthService.updateProfile({
        // ── Personal ─────────────────────────────────────────────────────────
        'first_name':   _firstNameController.text,
        'last_name':    _lastNameController.text,
        'display_name': _displayNameController.text,
        'email':        _emailController.text,
        if (apiDob.isNotEmpty) 'dob':          apiDob,
        if (apiDob.isNotEmpty) 'birth_date':   apiDob,
        if (apiDob.isNotEmpty) 'birthday':     apiDob,
        if (apiDob.isNotEmpty) 'date_of_birth': apiDob,
        'gender':       _genderController.text,
        'blood_group':  _bloodGroupController.text,
        'profile_photo': _selectedProfilePhoto,

        // ── Business ─────────────────────────────────────────────────────────
        'company_name':         _companyController.text,
        'business_category':    _classificationController.text,
        'experience':           _experienceController.text,
        'business_description': _productsController.text,
        'gst_number':           _gstNumberController.text,
        'website':              _websiteController.text,

        // ── Social links ──────────────────────────────────────────────────────
        'linkedin':  _linkedinController.text,
        'facebook':  _facebookController.text,
        'instagram': _instagramController.text,
        'twitter':   _twitterController.text,

        // ── Family ────────────────────────────────────────────────────────────
        'spouse_name':    _spouseNameController.text,
        if (apiAnniversary.isNotEmpty) 'anniversary':         apiAnniversary,
        if (apiAnniversary.isNotEmpty) 'anniversary_date':    apiAnniversary,
        if (apiAnniversary.isNotEmpty) 'wedding_anniversary': apiAnniversary,

        // ── Residential address ───────────────────────────────────────────────
        'residential_address': _address1Controller.text,
        'residential_city':    _cityController.text,
        'residential_state':   _stateController.text,
        'residential_pincode': _pincodeController.text,
        // legacy keys kept so older backend code still works
        'address_line_1': _address1Controller.text,
        'address':        _address1Controller.text,
        'city':           _cityController.text,
        'state':          _stateController.text,
        'pincode':        _pincodeController.text,

        // ── Office address ────────────────────────────────────────────────────
        'office_address': _officeAddressController.text,
        'office_city':    _officeCityController.text,
        'office_state':   _officeStateController.text,
        'office_pincode': _officePincodeController.text,

        // ── KYC ───────────────────────────────────────────────────────────────
        'aadhar_number':        _aadharNumberController.text,
        'aadhar_card_file':     _selectedAadharPhoto,
        'pan_number':           _panNumberController.text,
        'pan_card_file':        _selectedPanPhoto,
        'gst_certificate_file': _selectedGstPhoto,
        'visiting_card_file':   _selectedVisitingPhoto,
      }, files: uploadFiles);

      final prefs = await SharedPreferences.getInstance();
      if (_address1Controller.text.isNotEmpty) {
        await prefs.setString('user_address_1', _address1Controller.text);
      }
      if (_cityController.text.isNotEmpty) {
        await prefs.setString('user_city', _cityController.text);
      }
      if (_stateController.text.isNotEmpty) {
        await prefs.setString('user_state', _stateController.text);
      }
      if (_pincodeController.text.isNotEmpty) {
        await prefs.setString('user_pincode', _pincodeController.text);
      }
      if (_dobController.text.isNotEmpty) {
        await prefs.setString('user_dob', _dobController.text);
        await prefs.setString('user_birthday', _dobController.text);
      }
      if (_anniversaryController.text.isNotEmpty) {
        await prefs.setString('user_anniversary', _anniversaryController.text);
        await prefs.setString('user_anniversary_date', _anniversaryController.text);
      }

      if (!mounted) return;

      setState(() {
        if (_companyController.text.isNotEmpty) {
          _profileCompany = _companyController.text;
        }
        if (_displayNameController.text.isNotEmpty) {
          _profileName = _displayNameController.text;
        } else if (_firstNameController.text.isNotEmpty) {
          _profileName = _firstNameController.text;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
        ),
      );

      // Refresh profile so updated picture and fields are re-synced
      await _fetchProfile();
    } catch (e) {
      debugPrint('Update profile error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _selectDate(
      BuildContext context,
      TextEditingController controller,
      ) async {
    DateTime initial = DateTime.now();
    final text = controller.text.trim();
    if (text.isNotEmpty) {
      final parts = text.split(RegExp(r'[-/]'));
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final d = int.tryParse(parts[2]);
          if (y != null && m != null && d != null) {
            initial = DateTime(y, m, d);
          }
        } else if (parts[2].length == 4) {
          final d = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final y = int.tryParse(parts[2]);
          if (y != null && m != null && d != null) {
            initial = DateTime(y, m, d);
          }
        }
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2101),
      builder: AppUI.datePickerTheme,
    );

    if (picked != null && mounted) {
      setState(() {
        controller.text =
        '${picked.day.toString().padLeft(2, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.secondary;
    final bgColor = AppColors.card;
    final cardColor = AppColors.card;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: goldColor,
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(
            color: Colors.redAccent,
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Manage your personal and business details',
              style: TextStyle(
                color: AppColors.onCard,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _buildStatusBadge(
                  'Profile: Approved',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Profile Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 24,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius:
                BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accentBorder,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_selectedProfileBytes != null) {
                        final b64 =
                            'data:image/jpeg;base64,${base64Encode(_selectedProfileBytes!)}';
                        ImageViewer.show(
                          context,
                          b64,
                          caption: _profileName,
                        );
                      } else if (_profileAvatar.isNotEmpty &&
                          !_profileAvatar.endsWith('.svg')) {
                        ImageViewer.show(
                          context,
                          _profileAvatar,
                          caption: _profileName,
                        );
                      }
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.isDarkMode.value
                                ? AppColors.modalInput
                                : Colors.white,
                            border: Border.all(
                              color: goldColor,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _selectedProfileBytes != null
                              ? Image.memory(
                                  _selectedProfileBytes!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  filterQuality: FilterQuality.high,
                                )
                              : (_profileAvatar.isNotEmpty &&
                                      !_profileAvatar.endsWith('.svg'))
                                  ? (ImageViewer.isBase64Image(_profileAvatar)
                                      ? Builder(builder: (_) {
                                          final bytes = ImageViewer.decodeBase64Image(_profileAvatar);
                                          if (bytes != null) {
                                            return Image.memory(
                                              bytes,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                              alignment: Alignment.center,
                                              filterQuality: FilterQuality.high,
                                            );
                                          }
                                          return Center(
                                            child: Icon(
                                              Icons.person,
                                              size: 64,
                                              color: AppColors.isDarkMode.value
                                                  ? goldColor
                                                  : AppColors.primary,
                                            ),
                                          );
                                        })
                                      : Image.network(
                                          ImageViewer.resolveUrl(_profileAvatar),
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                          filterQuality: FilterQuality.high,
                                          errorBuilder: (_, __, ___) {
                                            return Center(
                                              child: Icon(
                                                Icons.person,
                                                size: 64,
                                                color: AppColors.isDarkMode.value
                                                    ? goldColor
                                                    : AppColors.primary,
                                              ),
                                            );
                                          },
                                        ))
                                  : Center(
                                      child: Icon(
                                        Icons.person,
                                        size: 64,
                                        color: AppColors.isDarkMode.value
                                            ? goldColor
                                            : AppColors.primary,
                                      ),
                                    ),
                        ),
                        if ((_profileAvatar.isNotEmpty &&
                                !_profileAvatar.endsWith('.svg')) ||
                            _selectedProfileBytes != null)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: goldColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: cardColor,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.zoom_in,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    _profileName.isNotEmpty
                        ? _profileName
                        : (widget.user['name'] ??
                        ''),
                    style: TextStyle(
                      color: goldColor,
                      fontSize: 16,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  Text(
                    _profileRole.isNotEmpty
                        ? _profileRole.toUpperCase()
                        : 'MEMBER',
                    style: TextStyle(
                      color: AppColors.onCard,
                      fontSize: 13,
                      fontWeight:
                      FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _profileChapter.isNotEmpty
                        ? _profileChapter
                        : 'RMB Member',
                    style: TextStyle(
                      color:
                      AppColors.onCardMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Account Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius:
                BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accentBorder,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACCOUNT INFO (READ-ONLY)',
                    style: TextStyle(
                      color: AppColors.cardHeading,
                      fontSize: 12,
                      fontWeight:
                      FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildAccountInfoRow(
                    'Mobile',
                    _profileMobile.isNotEmpty
                        ? _profileMobile
                        : (widget.user['mobile'] ??
                        ''),
                  ),

                  if (_profileEmail.isNotEmpty)
                    _buildAccountInfoRow(
                      'Email',
                      _profileEmail,
                    ),

                  _buildAccountInfoRow(
                    'Chapter',
                    _profileChapter.isNotEmpty
                        ? _profileChapter
                        : 'N/A',
                  ),

                  _buildAccountInfoRow(
                    'Company',
                    _companyController.text.isNotEmpty
                        ? _companyController.text
                        : (_profileCompany.isNotEmpty
                            ? _profileCompany
                            : 'N/A'),
                  ),

                  _buildAccountInfoRow(
                    'Role',
                    _profileRole.isNotEmpty
                        ? _profileRole
                        .replaceAll('_', ' ')
                        .toUpperCase()
                        : 'MEMBER',
                  ),

                  Padding(
                    padding:
                    const EdgeInsets.symmetric(
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(
                            color: AppColors
                                .onCardMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration:
                          BoxDecoration(
                            color:
                            const Color(
                              0xFF00C853,
                            ),
                            borderRadius:
                            BorderRadius
                                .circular(4),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  Divider(
                    color: AppColors.onRecordCardDivider,
                    thickness: 1,
                  ),
                  const SizedBox(height: 10),

                  // Business Details
                  Row(
                    children: [
                      Icon(
                        Icons.business_center,
                        size: 15,
                        color: AppColors.cardHeading,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'BUSINESS DETAILS',
                        style: TextStyle(
                          color: AppColors.cardHeading,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  _buildAccountInfoRow(
                    'Company Name',
                    _companyController.text.isNotEmpty
                        ? _companyController.text
                        : (_profileCompany.isNotEmpty
                            ? _profileCompany
                            : 'N/A'),
                  ),

                  if (_productsController.text.isNotEmpty)
                    _buildAccountInfoRow(
                      'Key Products / Services',
                      _productsController.text,
                    ),

                  const SizedBox(height: 10),
                  Divider(
                    color: AppColors.onRecordCardDivider,
                    thickness: 1,
                  ),
                  const SizedBox(height: 10),

                  // Address Details
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 15,
                        color: AppColors.cardHeading,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ADDRESS DETAILS',
                        style: TextStyle(
                          color: AppColors.cardHeading,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  _buildAccountInfoRow(
                    'Address',
                    _formattedAddress(),
                  ),

                  if (_cityController.text.isNotEmpty || _stateController.text.isNotEmpty)
                    _buildAccountInfoRow(
                      'City / State',
                      [
                        if (_cityController.text.isNotEmpty) _cityController.text,
                        if (_stateController.text.isNotEmpty) _stateController.text,
                      ].join(', '),
                    ),

                  if (_pincodeController.text.isNotEmpty)
                    _buildAccountInfoRow(
                      'Pincode',
                      _pincodeController.text,
                    ),

                  const SizedBox(height: 10),
                  Divider(
                    color: AppColors.onRecordCardDivider,
                    thickness: 1,
                  ),
                  const SizedBox(height: 10),

                  // Birthday & Anniversary Details
                  Row(
                    children: [
                      Icon(
                        Icons.cake,
                        size: 15,
                        color: AppColors.cardHeading,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'BIRTHDAY & ANNIVERSARY DETAILS',
                        style: TextStyle(
                          color: AppColors.cardHeading,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  _buildAccountInfoRow(
                    'Birthday / Date of Birth',
                    _dobController.text.isNotEmpty
                        ? _dobController.text
                        : 'Not provided',
                  ),

                  _buildAccountInfoRow(
                    'Anniversary Date',
                    _anniversaryController.text.isNotEmpty
                        ? _anniversaryController.text
                        : 'Not provided',
                  ),

                  if (_spouseNameController.text.isNotEmpty)
                    _buildAccountInfoRow(
                      'Spouse Name',
                      _spouseNameController.text,
                    ),

                  if (_genderController.text.isNotEmpty)
                    _buildAccountInfoRow(
                      'Gender',
                      _genderController.text,
                    ),

                  if (_bloodGroupController.text.isNotEmpty)
                    _buildAccountInfoRow(
                      'Blood Group',
                      _bloodGroupController.text,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Forms Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius:
                BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accentBorder,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset:
                    const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // Tabs
                  SingleChildScrollView(
                    scrollDirection:
                    Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTab(
                          'Personal',
                          Icons.person,
                        ),
                        const SizedBox(width: 8),
                        _buildTab(
                          'Business',
                          Icons.business_center,
                        ),
                        const SizedBox(width: 8),
                        _buildTab(
                          'Family',
                          Icons.family_restroom,
                        ),
                        const SizedBox(width: 8),
                        _buildTab(
                          'Address',
                          Icons.location_on,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (_selectedTab == 'Personal') ...[
                    _buildFormInput(
                      'First Name',
                      _firstNameController,
                      readOnly: true,
                    ),
                    _buildFormInput(
                      'Last Name',
                      _lastNameController,
                      readOnly: true,
                    ),
                    _buildFormInput(
                      'Display Name',
                      _displayNameController,
                    ),
                    _buildFormInput(
                      'Email',
                      _emailController,
                      readOnly: true,
                    ),
                    _buildFormInput(
                      'Date of Birth',
                      _dobController,
                      isDate: true,
                    ),
                    _buildGenderSelector(),
                    _buildFormInput(
                      'Blood Group',
                      _bloodGroupController,
                      hint: 'e.g. O+',
                    ),
                    _buildFilePickerInput(
                      'Profile Photo',
                      _selectedProfilePhoto,
                      () => _pickFile(
                        (val) => _selectedProfilePhoto = val,
                        onFilePicked: (bytes, name) {
                          _selectedProfileBytes = bytes;
                          _selectedProfilePhoto = name;
                        },
                      ),
                    ),
                  ] else if (_selectedTab ==
                      'Business') ...[
                    _buildFormInput(
                      'Company Name',
                      _companyController,
                    ),
                    _buildFormInput(
                      'Key Products / Services',
                      _productsController,
                    ),
                  ] else if (_selectedTab ==
                      'Family') ...[
                    _buildFormInput(
                      'Spouse Name',
                      _spouseNameController,
                    ),
                    _buildFormInput(
                      'Anniversary',
                      _anniversaryController,
                      isDate: true,
                    ),
                  ] else if (_selectedTab ==
                      'Address') ...[
                    _buildFormInput(
                      'Address Line 1',
                      _address1Controller,
                    ),
                    _buildFormInput(
                      'City',
                      _cityController,
                    ),
                    _buildFormInput(
                      'State',
                      _stateController,
                    ),
                    _buildFormInput(
                      'Pincode',
                      _pincodeController,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style:
                      ElevatedButton.styleFrom(
                        backgroundColor:
                        goldColor,
                        foregroundColor:
                        AppColors.card,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                      onPressed: _isUpdating
                          ? null
                          : _updateProfile,
                      icon: _isUpdating
                          ? SizedBox(
                        width: 18,
                        height: 18,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                          AppColors.card,
                        ),
                      )
                          : const Icon(
                        Icons.send,
                        size: 18,
                      ),
                      label: Text(
                        _isUpdating
                            ? 'Updating...'
                            : 'Submit for Approval',
                        style: const TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF00C853)
            .withValues(alpha: 0.15),
        border: Border.all(
          color: const Color(0xFF00C853),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF00E676),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAccountInfoRow(
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.onCardMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppColors.onCard,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
      String title,
      IconData icon,
      ) {
    final bool isSelected =
        _selectedTab == title;

    final goldColor = AppColors.secondary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 16,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? goldColor
              : (AppColors.isDarkMode.value
                  ? AppColors.modalInput
                  : AppColors.card),
          borderRadius:
          BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? goldColor
                : AppColors.inputBorder.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? const Color(0xFF1D428A)
                  : (AppColors.isDarkMode.value
                      ? goldColor
                      : AppColors.primary),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF1D428A)
                    : AppColors.onCard,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    final options = ['Male', 'Female', 'Others'];
    final currentGender = _genderController.text.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gender',
            style: TextStyle(
              color: AppColors.onCardLabel,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: options.map((option) {
              final isSelected = currentGender.toLowerCase() == option.toLowerCase() ||
                  (option == 'Others' &&
                      (currentGender.toLowerCase() == 'other' ||
                          currentGender.toLowerCase() == 'others'));
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: option != options.last ? 8.0 : 0.0,
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _genderController.text = option;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.secondary
                            : (AppColors.isDarkMode.value
                                ? AppColors.modalInput
                                : AppColors.card),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.secondary
                              : AppColors.inputBorder,
                          width: isSelected ? 2.0 : 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            option == 'Male'
                                ? Icons.male
                                : (option == 'Female'
                                    ? Icons.female
                                    : Icons.people_alt_outlined),
                            size: 18,
                            color: isSelected
                                ? const Color(0xFF1D428A)
                                : (AppColors.isDarkMode.value
                                    ? AppColors.inputBorder
                                    : AppColors.onCard),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            option,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF1D428A)
                                  : AppColors.onCard,
                              fontSize: 13,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePickerInput(
      String label,
      String? selectedFileName,
      VoidCallback onTap,
      ) {
    final cardColor = AppColors.card;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.onCardLabel,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 44,
              padding:
              const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              decoration: BoxDecoration(
                color: AppColors.isDarkMode.value
                    ? AppColors.modalInput
                    : cardColor,
                borderRadius:
                BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.inputBorder,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.upload_file,
                    color:
                    AppColors.inputBorder,
                    size: 18,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      selectedFileName ??
                          'Choose File',
                      style: TextStyle(
                        color:
                        selectedFileName != null
                            ? AppColors.onCard
                            : AppColors.textMuted,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormInput(
      String label,
      TextEditingController controller, {
        String? hint,
        bool isDate = false,
        bool readOnly = false,
      }) {
    final cardColor = AppColors.card;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.onCardLabel,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Container(
            height: 44,
            decoration: BoxDecoration(
              color: readOnly
                  ? (AppColors.isDarkMode.value
                      ? AppColors.modalInput.withValues(alpha: 0.6)
                      : AppColors.primary.withValues(alpha: 0.06))
                  : (AppColors.isDarkMode.value
                      ? AppColors.modalInput
                      : cardColor),
              borderRadius:
              BorderRadius.circular(10),
              border: Border.all(
                color: readOnly
                    ? AppColors.inputBorder.withValues(alpha: 0.45)
                    : AppColors.inputBorder,
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: controller,
              readOnly:
              isDate || readOnly,
              enableInteractiveSelection:
              !readOnly,
              cursorColor: AppColors.inputBorder,
              onTap: isDate
                  ? () => _selectDate(
                context,
                controller,
              )
                  : null,
              style: TextStyle(
                color: AppColors.onCard,
                fontSize: 14,
              ),
              decoration:
              InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color:
                  AppColors.textMuted,
                ),
                border:
                InputBorder.none,
                contentPadding:
                const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                suffixIcon: isDate
                    ? Icon(
                  Icons.calendar_today,
                  color:
                  AppColors.inputBorder,
                  size: 18,
                )
                    : (readOnly
                    ? Icon(
                  Icons.lock_outline,
                  color: AppColors
                      .onCardMuted,
                  size: 16,
                )
                    : null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
