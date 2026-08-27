import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../infrastructure/update_service.dart';
import '../theme/app_theme.dart';

class UpdateDialog extends StatelessWidget {
  final AppVersionInfo versionInfo;

  const UpdateDialog({super.key, required this.versionInfo});

  Future<void> _launchUpdateUrl() async {
    final uri = Uri.parse(versionInfo.downloadUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch update URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !versionInfo.forceUpdate,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.system_update_rounded, color: AppColors.cyan, size: 48),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Update Available',
                style: GoogleFonts.orbitron(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              
              // Version info
              Text(
                'Version ${versionInfo.version} is ready to install',
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Release notes
              if (versionInfo.releaseNotes.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.isLight ? AppColors.surfaceLight : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Text(
                    versionInfo.releaseNotes,
                    style: GoogleFonts.rajdhani(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
              const SizedBox(height: 24),
              
              // Actions
              EsportsButton(
                onPressed: _launchUpdateUrl,
                label: 'UPDATE NOW',
              ),
              
              if (!versionInfo.forceUpdate) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                  ),
                  child: Text(
                    'LATER',
                    style: GoogleFonts.rajdhani(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
