import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../infrastructure/api_client.dart';
import '../theme/app_theme.dart';
import '../providers/match_provider.dart';

class RescheduleDialog extends ConsumerStatefulWidget {
  final String tournamentId;
  final String? matchdayId;
  final String? matchId;
  final DateTime? currentDate;
  final bool isMatchday;

  const RescheduleDialog({
    super.key,
    required this.tournamentId,
    this.matchdayId,
    this.matchId,
    this.currentDate,
    this.isMatchday = true,
  });

  @override
  ConsumerState<RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends ConsumerState<RescheduleDialog> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedMatchdayId;
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.currentDate ?? DateTime.now();
    _selectedTime = widget.currentDate != null
        ? TimeOfDay.fromDateTime(widget.currentDate!)
        : const TimeOfDay(hour: 18, minute: 0); // Default KO 6:00 PM
    _selectedMatchdayId = widget.matchdayId;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: (AppColors.isLight ? ThemeData.light() : ThemeData.dark()).copyWith(
            colorScheme: AppColors.isLight
                ? ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.surface,
                    onSurface: AppColors.textPrimary,
                  )
                : ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.black,
                    surface: AppColors.surface,
                    onSurface: Colors.white,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    if (widget.isMatchday) return; // Matchdays are date-only

    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (context, child) {
        return Theme(
          data: (AppColors.isLight ? ThemeData.light() : ThemeData.dark()).copyWith(
            colorScheme: AppColors.isLight
                ? ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.surface,
                    onSurface: AppColors.textPrimary,
                  )
                : ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.black,
                    surface: AppColors.surface,
                    onSurface: Colors.white,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_selectedDate == null) return;
    
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      if (widget.isMatchday) {
        await client.updateMatchdaySchedule(widget.tournamentId, widget.matchdayId!, _selectedDate);
      } else {
        final dt = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime?.hour ?? 18,
          _selectedTime?.minute ?? 0,
        );
        await client.rescheduleMatch(
          widget.tournamentId,
          widget.matchId!,
          dt,
          _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
          _selectedMatchdayId,
        );
      }
      
      // Invalidate providers
      ref.invalidate(tournamentBracketProvider(widget.tournamentId));
      ref.invalidate(matchdaysProvider(widget.tournamentId));
      ref.invalidate(leagueStandingsProvider(widget.tournamentId));
      ref.invalidate(tournamentPlayerStatsProvider(widget.tournamentId));
      if (widget.matchdayId != null) {
        ref.invalidate(matchdayMatchesProvider((tournamentId: widget.tournamentId, matchdayId: widget.matchdayId!)));
      }
      if (_selectedMatchdayId != null && _selectedMatchdayId != widget.matchdayId) {
        ref.invalidate(matchdayMatchesProvider((tournamentId: widget.tournamentId, matchdayId: _selectedMatchdayId!)));
      }
      ref.invalidate(tournamentProgressProvider(widget.tournamentId));
      final authUserId = ref.read(authStateProvider);
      if (authUserId != null) {
        ref.invalidate(playerScheduledMatchesProvider(authUserId));
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        final errMsg = ApiClient.formatErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg, style: const TextStyle(color: Colors.white))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isMatchday) {
      ref.listen(matchdaysProvider(widget.tournamentId), (prev, next) {
        final nextMatchdays = (next.value?['matchdays'] as List<dynamic>? ?? []);
        if (nextMatchdays.isNotEmpty && _selectedMatchdayId == null) {
          final currentMd = widget.matchdayId != null
              ? nextMatchdays.where((m) => m['id']?.toString() == widget.matchdayId).firstOrNull ?? nextMatchdays.first
              : nextMatchdays.first;
          setState(() {
            _selectedMatchdayId = currentMd['id']?.toString();
            if (currentMd['scheduled_date'] != null) {
              try {
                _selectedDate = DateTime.parse(currentMd['scheduled_date'].toString());
              } catch (_) {}
            }
          });
        }
      });
    }

    final matchdaysAsync = !widget.isMatchday
        ? ref.watch(matchdaysProvider(widget.tournamentId))
        : null;
    final matchdays = (matchdaysAsync?.value?['matchdays'] as List<dynamic>? ?? []);

    final effectiveMatchdayId = _selectedMatchdayId ??
        (matchdays.isNotEmpty
            ? (widget.matchdayId != null && matchdays.any((m) => m['id']?.toString() == widget.matchdayId)
                ? widget.matchdayId
                : matchdays.first['id']?.toString())
            : null);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isMatchday ? 'RESCHEDULE MATCHDAY' : 'RESCHEDULE MATCH',
              style: GoogleFonts.orbitron(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // For Matchdays: Pick date. For Matches: Pick target Matchday
            if (widget.isMatchday) ...[
              Text('Date', style: GoogleFonts.rajdhani(color: AppColors.textMuted)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDate != null 
                          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                          : 'Select Date',
                        style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Text('Target Matchday', style: GoogleFonts.rajdhani(color: AppColors.textMuted)),
              const SizedBox(height: 8),
              if (matchdaysAsync != null && matchdaysAsync.isLoading)
                Center(child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ))
              else if (matchdays.isEmpty)
                Text('No matchdays available', style: GoogleFonts.rajdhani(color: AppColors.textSecondary))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: effectiveMatchdayId,
                      dropdownColor: AppColors.surface,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                      items: matchdays.map((md) {
                        final mdId = md['id'].toString();
                        final mdNum = md['matchday_number']?.toString() ?? '';
                        final dateStr = md['scheduled_date']?.toString() ?? 'No Date';
                        return DropdownMenuItem<String>(
                          value: mdId,
                          child: Text(
                            'Matchday $mdNum ($dateStr)',
                            style: GoogleFonts.rajdhani(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _selectedMatchdayId = val;
                          final chosenMd = matchdays.where((m) => m['id']?.toString() == val).firstOrNull;
                          if (chosenMd != null && chosenMd['scheduled_date'] != null) {
                            try {
                              _selectedDate = DateTime.parse(chosenMd['scheduled_date'].toString());
                            } catch (_) {}
                          }
                        });
                      },
                    ),
                  ),
                ),
            ],
            
            if (!widget.isMatchday) ...[
              const SizedBox(height: 16),
              Text('Kickoff Time (Default: 6:00 PM)', style: GoogleFonts.rajdhani(color: AppColors.textMuted)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _selectedTime != null 
                          ? _selectedTime!.format(context)
                          : '6:00 PM',
                        style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Reason (Optional)', style: GoogleFonts.rajdhani(color: AppColors.textMuted)),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                style: GoogleFonts.rajdhani(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceLight.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'e.g. Player unavailable',
                  hintStyle: TextStyle(color: AppColors.textDim),
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : Text(
                          'SAVE',
                          style: GoogleFonts.orbitron(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
