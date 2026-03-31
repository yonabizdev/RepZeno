import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import '../models/user_profile.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/glass_app_bar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _genderController = TextEditingController();
  final _ftController = TextEditingController();
  final _inController = TextEditingController();
  final _dobController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = true;

  @override
  void dispose() {
    _nameController.dispose();
    _genderController.dispose();
    _ftController.dispose();
    _inController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _populateProfile(UserProfile profile) {
    if (_isLoading) {
      _nameController.text = profile.name ?? '';
      if (profile.height != null && profile.height! > 0) {
        final totalInches = profile.height! / 2.54;
        final feet = (totalInches / 12).floor();
        final inches = (totalInches % 12).round();
        
        _ftController.text = feet > 0 ? feet.toString() : '';
        _inController.text = inches.toString();
      }
      _selectedGender = profile.gender;
      _genderController.text = _selectedGender ?? '';
      _dobController.text = profile.dateOfBirth ?? '';
      _isLoading = false;
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    
    double? customHeight;
    final ftString = _ftController.text.trim();
    final inString = _inController.text.trim();
    
    if (ftString.isNotEmpty || inString.isNotEmpty) {
      final feet = double.tryParse(ftString) ?? 0;
      final inches = double.tryParse(inString) ?? 0;
      
      final totalInches = (feet * 12) + inches;
      if (totalInches > 0) {
        customHeight = num.parse((totalInches * 2.54).toStringAsFixed(1)).toDouble();
      }
    }

    final dobString = _dobController.text.trim();

    final profile = UserProfile(
      name: name.isEmpty ? null : name,
      height: customHeight,
      gender: _selectedGender,
      dateOfBirth: dobString.isEmpty ? null : dobString,
    );

    await ref.read(userProfileProvider.notifier).saveProfile(profile);

    if (mounted) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully!')),
      );
    }
  }

  Future<void> _selectDateOfBirth() async {
    final initialDate = _dobController.text.isNotEmpty 
      ? DateTime.tryParse(_dobController.text) ?? DateTime.now() 
      : DateTime.now().subtract(const Duration(days: 365 * 25)); // Default to ~25 years old

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
         return Theme(
           data: Theme.of(context).copyWith(
             colorScheme: const ColorScheme.dark(
               primary: AppTheme.primary,
               surface: AppTheme.surfaceElevated,
               onPrimary: Colors.white,
               onSurface: Colors.white,
             ),
           ),
           child: child!,
         );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        final options = ['Male', 'Female', 'Other', 'Prefer not to say'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Gender',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...options.map((option) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    title: Text(
                      option,
                      style: TextStyle(
                        fontWeight: _selectedGender == option ? FontWeight.bold : FontWeight.normal,
                        color: _selectedGender == option ? AppTheme.primary : Colors.white,
                      ),
                    ),
                    trailing: _selectedGender == option ? const Icon(Icons.check_circle, color: AppTheme.primary) : null,
                    onTap: () {
                      setState(() {
                        _selectedGender = option;
                        _genderController.text = option;
                      });
                      Navigator.pop(context);
                    },
                  )),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final topContentInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('My Profile')),
      body: AppBackdrop(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error loading profile: $err')),
          data: (profile) {
            if (profile != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                 if (mounted) {
                    setState(() {
                      _populateProfile(profile);
                    });
                 }
              });
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(16, topContentInset, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Personal Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          prefixIcon: const Icon(Icons.person),
                          filled: true,
                          fillColor: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ftController,
                              decoration: InputDecoration(
                                labelText: 'Feet',
                                prefixIcon: const Icon(Icons.height),
                                hintText: '5',
                                filled: true,
                                fillColor: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _inController,
                              decoration: InputDecoration(
                                labelText: 'Inches',
                                prefixIcon: const Icon(Icons.height),
                                hintText: '8',
                                filled: true,
                                fillColor: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _genderController,
                        readOnly: true,
                        onTap: _showGenderPicker,
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: const Icon(Icons.wc),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                          filled: true,
                          fillColor: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: _selectDateOfBirth,
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          prefixIcon: const Icon(Icons.cake),
                          filled: true,
                          fillColor: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Save Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
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
