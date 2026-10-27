import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../models/note.dart';
import '../services/api_service.dart';

class ScanImportScreen extends StatefulWidget {
  final String initialMode;
  final void Function(NoteItem note)? onExportToNotes;
  final VoidCallback? onNavigateToNotes;

  const ScanImportScreen({
    super.key,
    this.initialMode = 'camera',
    this.onExportToNotes,
    this.onNavigateToNotes,
  });

  @override
  State<ScanImportScreen> createState() => _ScanImportScreenState();
}

class _ScanImportScreenState extends State<ScanImportScreen> {
  late String _activeMode;
  bool _flashOn = false;
  int _capturedCount = 1;
  late TextEditingController _textController;
  late TextEditingController _pasteController;
  bool _isExtracting = false;
  bool _isGenerating = false;
  String? _extractionMethod;
  String? _sourceFilename;
  bool? _isBackendOnline;

  final String _sampleOcrText = """# Ebbinghaus Forgetting Curve

The Ebbinghaus Forgetting Curve demonstrates how learned information decays exponentially over time when there is no active attempt to retain it.

Key Takeaways:
1. Memory retention drops sharply within the first 24 hours (up to 70% loss).
2. Spaced Repetition interrupts the decay trajectory and flattens the curve over progressive review intervals.
3. Overlearning increases baseline cognitive durability.""";

  @override
  void initState() {
    super.initState();
    _activeMode = widget.initialMode;
    _textController = TextEditingController(text: _sampleOcrText);
    _pasteController = TextEditingController();
    _checkBackendStatus();
  }

  Future<void> _checkBackendStatus() async {
    try {
      final res = await ApiService.checkHealth();
      if (mounted) {
        setState(() {
          _isBackendOnline = res['status'] == 'ok';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isBackendOnline = false;
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Pick image via camera, compress to lightweight size, upload for backend OCR
  Future<void> _captureFromCamera() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photo == null) return;

      setState(() {
        _isExtracting = true;
        _sourceFilename = photo.name;
      });

      final bytes = await photo.readAsBytes();
      final res = await ApiService.extractFromBytes(bytes, photo.name);
      final text = res['extracted_text'] as String? ?? '';

      setState(() {
        _textController.text = text;
        _extractionMethod = res['extraction_method'] as String? ?? res['method'] as String? ?? 'OCR';
        _capturedCount++;
        _isExtracting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Extracted ${text.length} characters using ${_extractionMethod!}!',
            ),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isExtracting = false);
      if (mounted) {
        _showErrorDialog(
          'Camera Extraction Failed',
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  /// Browse and upload PDF, DOCX, TXT, or Image files
  Future<void> _pickAndExtractFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;

      // 25MB validation
      if (picked.size > 25 * 1024 * 1024) {
        _showErrorDialog(
          'File Oversized',
          'The selected file is ${(picked.size / (1024 * 1024)).toStringAsFixed(1)} MB. Maximum supported upload size is 25 MB.',
        );
        return;
      }

      setState(() {
        _isExtracting = true;
        _sourceFilename = picked.name;
      });

      Uint8List? bytes = picked.bytes;
      if (bytes == null && picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        throw Exception('The selected file appears empty or unreadable.');
      }

      final res = await ApiService.extractFromBytes(bytes, picked.name);
      final text = res['extracted_text'] as String? ?? '';
      final method = res['extraction_method'] as String? ?? res['method'] as String? ?? 'Document Parser';

      setState(() {
        _textController.text = text;
        _extractionMethod = method;
        _isExtracting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Extracted ${text.length} characters from ${picked.name} ($method)!',
            ),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isExtracting = false);
      if (mounted) {
        _showErrorDialog(
          'Upload Extraction Failed',
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  /// Clean & format text
  void _fixTextFormat() {
    final raw = _textController.text;
    if (raw.trim().isEmpty) return;
    // Replace multiple empty lines with double newline, trim line ends
    final cleaned = raw
        .split('\n')
        .map((l) => l.trimRight())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    setState(() {
      _textController.text = cleaned;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cleaned text whitespace, bullets, and line formatting!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// AI Note Generation from editable text preview
  Future<void> _exportToNotes() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showErrorDialog(
        'Empty Study Material',
        'Cannot generate notes from empty text. Please scan a page, upload a document, or paste lecture text first.',
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      String? cleanTitle;
      if (_sourceFilename != null && _sourceFilename!.isNotEmpty) {
        cleanTitle = _sourceFilename!
            .split('.')
            .first
            .replaceAll(RegExp(r'[-_]'), ' ')
            .trim();
      }

      final note = await ApiService.generateNotes(
        text: text,
        title: cleanTitle,
      );

      setState(() => _isGenerating = false);

      if (widget.onExportToNotes != null) {
        widget.onExportToNotes!(note);
      } else if (widget.onNavigateToNotes != null) {
        widget.onNavigateToNotes!();
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        _showErrorDialog(
          'Note Generation Failed',
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubHeader(),
                    const SizedBox(height: 12),
                    _buildSegmentedSwitcher(),
                    const SizedBox(height: 14),
                    if (_activeMode == 'camera') ...[
                      _buildCameraViewfinder(),
                      const SizedBox(height: 14),
                      _buildCaptureRibbon(),
                    ] else if (_activeMode == 'upload') ...[
                      _buildUploadModeArea(),
                    ] else ...[
                      _buildPasteModeArea(),
                    ],
                    const SizedBox(height: 16),
                    _buildExtractedTextSheet(),
                    const SizedBox(height: 16),
                    _buildAiSuggestionTipCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.document_scanner_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'StudyBuddy AI',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                'Scan And Import',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: _checkBackendStatus,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _isBackendOnline == true
                    ? AppColors.emeraldBg
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isBackendOnline == true
                      ? AppColors.emerald
                      : AppColors.surfaceContainerHigh,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 7,
                    color: _isBackendOnline == true
                        ? AppColors.emerald
                        : (_isBackendOnline == false ? AppColors.error : AppColors.amber),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isBackendOnline == true ? 'AI Online' : 'AI Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _isBackendOnline == true
                          ? AppColors.emerald
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.surfaceContainerHigh),
            ),
            child: const Row(
              children: [
                Text('🔥', style: TextStyle(fontSize: 13)),
                SizedBox(width: 4),
                Text(
                  '6 Days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import Study Material',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Snap notes, textbook passages, or lecture slides',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLow,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.lightbulb_outline_rounded,
                size: 20, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tip: Keep pages flat and well-lit for optimal OCR extraction!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _buildSegmentButton('camera', Icons.photo_camera_rounded, 'Camera Scan'),
          _buildSegmentButton('upload', Icons.upload_file_rounded, 'Upload File'),
          _buildSegmentButton('paste', Icons.content_paste_rounded, 'Paste Text'),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String mode, IconData icon, String label) {
    final isSelected = _activeMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceContainerLowest : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraViewfinder() {
    return GestureDetector(
      onTap: _isExtracting ? null : _captureFromCamera,
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          color: AppColors.inverseSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryContainer.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background notebook pattern
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF1E2333),
                  child: CustomPaint(
                    painter: _GridGuidePainter(),
                  ),
                ),
              ),

              // Corner Alignment Guides
              Positioned(
                left: 20,
                top: 20,
                child: _buildCornerGuide(true, true),
              ),
              Positioned(
                right: 20,
                top: 20,
                child: _buildCornerGuide(false, true),
              ),
              Positioned(
                left: 20,
                bottom: 20,
                child: _buildCornerGuide(true, false),
              ),
              Positioned(
                right: 20,
                bottom: 20,
                child: _buildCornerGuide(false, false),
              ),

              // Top Viewfinder Toolbar
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.inverseSurface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.document_scanner_rounded,
                              size: 14, color: AppColors.tertiaryFixed),
                          SizedBox(width: 4),
                          Text(
                            'Auto Edge-Detect',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inverseOnSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _buildViewfinderIconBtn(
                          icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          onTap: () {
                            setState(() {
                              _flashOn = !_flashOn;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildViewfinderIconBtn(
                          icon: Icons.tune_rounded,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Center Action Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.inverseSurface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isExtracting) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'AI OCR Processing Page...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.circle, size: 8, color: AppColors.emerald),
                        const SizedBox(width: 6),
                        const Text(
                          'Tap Viewfinder to Snap & OCR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Live In-Viewport Progress Toast
              if (_isExtracting)
                Positioned(
                  bottom: 14,
                  left: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.sync_rounded,
                                      size: 16, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Backend AI OCR in progress...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            backgroundColor: AppColors.surfaceContainer,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCornerGuide(bool isLeft, bool isTop) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: AppColors.primaryFixed, width: 3.5)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: AppColors.primaryFixed, width: 3.5)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: AppColors.primaryFixed, width: 3.5)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: AppColors.primaryFixed, width: 3.5)
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildViewfinderIconBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.inverseSurface.withValues(alpha: 0.8),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  Widget _buildCaptureRibbon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Captured Pages',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_capturedCount Page${_capturedCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onPrimaryFixed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _capturedCount = 0;
                    _textController.clear();
                  });
                },
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Thumbnails Strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildThumbnailCard(1, 'Captured Page 1', isProcessed: true, isActive: true),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _isExtracting ? null : _captureFromCamera,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 64,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded,
                            size: 22, color: AppColors.onSurfaceVariant),
                        SizedBox(height: 4),
                        Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Shutter controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Undo
              IconButton(
                icon: const Icon(Icons.undo_rounded, size: 24, color: AppColors.onSurfaceVariant),
                onPressed: () {
                  if (_capturedCount > 0) {
                    setState(() {
                      _capturedCount--;
                    });
                  }
                },
              ),
              // Shutter button
              InkWell(
                onTap: _isExtracting ? null : _captureFromCamera,
                borderRadius: BorderRadius.circular(36),
                child: Container(
                  width: 70,
                  height: 70,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      width: 4,
                    ),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    child: _isExtracting
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          )
                        : const Icon(Icons.photo_camera_rounded,
                            color: Colors.white, size: 28),
                  ),
                ),
              ),
              // Export button
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _exportToNotes,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(_isGenerating ? 'Generating...' : 'Done ($_capturedCount)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailCard(int index, String label,
      {bool isProcessed = false, bool isActive = false}) {
    return Container(
      width: 64,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: isActive ? Border.all(color: AppColors.primary, width: 2) : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.article_rounded,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              size: 32,
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isProcessed ? AppColors.emerald : AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isProcessed ? '✓' : 'OCR',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadModeArea() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.secondaryFixed,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isExtracting ? Icons.sync_rounded : Icons.cloud_upload_rounded,
              size: 30,
              color: AppColors.onSecondaryFixedVariant,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Upload Lecture Slides or Syllabus',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Supports PDF, DOCX, TXT, PNG, JPG (up to 25MB)',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isExtracting ? null : _pickAndExtractFile,
            icon: _isExtracting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.folder_open_rounded, size: 16),
            label: Text(_isExtracting ? 'Extracting Text...' : 'Browse Files'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasteModeArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste Lecture Transcript or Text',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pasteController,
            maxLines: 4,
            onChanged: (val) {
              setState(() {
                _textController.text = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Paste lecture transcription, textbook notes or syllabus...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.outline),
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  if (_pasteController.text.trim().isNotEmpty) {
                    setState(() {
                      _textController.text = _pasteController.text;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pasted text loaded into preview!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Apply to Preview', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedTextSheet() {
    final wordCount = _textController.text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final charCount = _textController.text.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.text_snippet_rounded,
                        size: 20, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Extracted Text Preview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.emeraldBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 13, color: AppColors.emerald),
                    const SizedBox(width: 3),
                    Text(
                      _extractionMethod ?? 'Auto-cleaned OCR',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Stats: $wordCount words • $charCount chars',
                style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
              const Text('•', style: TextStyle(color: AppColors.outline)),
              Text(
                _sourceFilename ?? 'Pasted / Scanned Text',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _textController,
              maxLines: 7,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.onSurface,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Extracted text will appear here. You can freely edit or polish it before generating notes.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isExtracting
                      ? null
                      : () {
                          if (_activeMode == 'camera') {
                            _captureFromCamera();
                          } else {
                            _pickAndExtractFile();
                          }
                        },
                  icon: const Icon(Icons.replay_rounded, size: 15),
                  label: const Text('Re-scan',
                      style: TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onSurface,
                    side: const BorderSide(color: AppColors.surfaceContainerHigh),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _fixTextFormat,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 15),
                  label: const Text('Fix Format',
                      style: TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryFixed,
                    foregroundColor: AppColors.onSecondaryFixedVariant,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _exportToNotes,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.note_add_rounded, size: 15),
                  label: Text(_isGenerating ? 'AI Processing...' : 'Export',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiSuggestionTipCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'StudyBuddy AI Note Deck',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Synthesize key definitions, pitfalls, and takeaways.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _isGenerating ? null : _exportToNotes,
            child: Text(
              _isGenerating ? 'Working...' : 'Generate',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    // 3x3 Grid
    canvas.drawLine(
        Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(2 * size.width / 3, 0),
        Offset(2 * size.width / 3, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, 2 * size.height / 3),
        Offset(size.width, 2 * size.height / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
