import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class CreateDriverAccountPage extends StatefulWidget {
  const CreateDriverAccountPage({super.key});

  @override
  State<CreateDriverAccountPage> createState() =>
      _CreateDriverAccountPageState();
}

class _CreateDriverAccountPageState extends State<CreateDriverAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _experienceController = TextEditingController();
  final _aadharNoController = TextEditingController();
  final _panNoController = TextEditingController();
  final _licenseController = TextEditingController();

  static const List<String> _statusOptions = [
    'available',
    'not_available',
    'driving',
  ];
  String _selectedStatus = 'available';
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;
  bool _isPickingPhoto = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _experienceController.dispose();
    _aadharNoController.dispose();
    _panNoController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_isPickingPhoto || _isSaving) {
      return;
    }

    setState(() {
      _isPickingPhoto = true;
    });

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (!mounted || picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedPhotoBytes = bytes;
        _selectedPhotoName = picked.name;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to pick photo. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingPhoto = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }

    final experienceText = _experienceController.text.trim();
    final parsedExperience = int.tryParse(experienceText);
    if (parsedExperience == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Experience is required'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    String? photoMediaId;
    if (_selectedPhotoBytes != null && _selectedPhotoBytes!.isNotEmpty) {
      final uploadResult = await _apiService.uploadMedia(
        fileBytes: _selectedPhotoBytes!,
        fileName: _selectedPhotoName ?? 'driver_photo.jpg',
        alt: _nameController.text.trim(),
      );

      if (uploadResult['success'] == true) {
        photoMediaId = uploadResult['mediaId']?.toString();
      } else {
        debugPrint(
          'Photo upload did not return success: ${uploadResult['message']}',
        );
      }
    }

    final result = await _apiService.createDriverProfile(
      name: _nameController.text,
      phone: _phoneController.text,
      address: _addressController.text,
      experience: parsedExperience,
      aadharNo: _aadharNoController.text,
      panNo: _panNoController.text,
      license: _licenseController.text,
      photoMediaId: photoMediaId,
      status: _selectedStatus,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver details saved successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? 'Unable to save details',
        ),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Create Driver Account',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enter Driver Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Use the same phone number as your login user account.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: (_isPickingPhoto || _isSaving)
                                  ? null
                                  : _pickPhoto,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF22C55E),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _isPickingPhoto
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF22C55E),
                                      ),
                                    )
                                  : const Icon(Icons.photo_library_outlined),
                              label: Text(
                                _selectedPhotoName == null
                                    ? 'Upload Photo (optional)'
                                    : 'Photo Selected',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedPhotoBytes != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _selectedPhotoBytes!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration('Name'),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration('Phone'),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Phone is required';
                          }
                          if (text.length < 8) {
                            return 'Enter a valid phone';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration('Address'),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Address is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _experienceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration('Experience (years)'),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Experience is required';
                          }

                          final parsed = int.tryParse(text);
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _aadharNoController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration(
                          'Aadhar Number (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _panNoController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration('PAN Number (optional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _licenseController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration('License (optional)'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: _fieldDecoration('Status'),
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        items: _statusOptions
                            .map(
                              (status) => DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedStatus = value;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
