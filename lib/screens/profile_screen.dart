import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _ftController = TextEditingController();
  final _inController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = true;

  @override
  void dispose() {
    _nameController.dispose();
    _ftController.dispose();
    _inController.dispose();
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

    final profile = UserProfile(
      name: name.isEmpty ? null : name,
      height: customHeight,
      gender: _selectedGender,
    );

    await ref.read(userProfileProvider.notifier).saveProfile(profile);

    if (mounted) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final topContentInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('My Profile')),
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
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: const Icon(Icons.wc),
                          filled: true,
                          fillColor: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        dropdownColor: AppTheme.surfaceElevated,
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                          DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedGender = val;
                          });
                        },
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
