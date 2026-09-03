import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/matna.dart';
import '../../models/student.dart';
import '../../services/mutun_service.dart';
import '../../services/students_service.dart';
import '../../widgets/common_widgets.dart';

/// تبويب المتون — متابعة حفظ كل طالب للمتون داخل المسار
class MutunTab extends StatefulWidget {
  final PathwayInfo pathway;
  final String teacherId;

  const MutunTab({
    super.key,
    required this.pathway,
    required this.teacherId,
  });

  @override
  State<MutunTab> createState() => _MutunTabState();
}

class _MutunTabState extends State<MutunTab>
    with AutomaticKeepAliveClientMixin {
  final MutunService _mutunService = MutunService();
  final StudentsService _studentsService = StudentsService();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_matna_${widget.pathway.id}',
        onPressed: () => _showAddMatnaDialog(context),
        icon: const Icon(Icons.playlist_add_rounded),
        label: const Text('إضافة متن',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<Matna>>(
        stream: _mutunService.watchPathwayMutun(
          teacherId: widget.teacherId,
          pathwayId: widget.pathway.id,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              message: 'حدث خطأ أثناء تحميل المتون',
              onRetry: () => setState(() {}),
            );
          }
          if (!snapshot.hasData) {
            return const ListSkeleton(itemCount: 4);
          }

          final mutun = snapshot.data!;
          if (mutun.isEmpty) {
            return EmptyState(
              icon: Icons.auto_stories_rounded,
              title: 'لا توجد متون بعد',
              message:
                  'أضف متون هذا المسار لتتابع حفظ طلابك فيها\nمثال: متن الآجرومية، تحفة الأطفال...',
              actionLabel: 'إضافة أول متن',
              onAction: () => _showAddMatnaDialog(context),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: mutun.length,
              itemBuilder: (context, index) => _MatnaCard(
                matna: mutun[index],
                pathway: widget.pathway,
                mutunService: _mutunService,
                studentsService: _studentsService,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddMatnaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AddMatnaDialog(
        service: _mutunService,
        teacherId: widget.teacherId,
        pathway: widget.pathway,
      ),
    );
  }
}

// ==================== بطاقة المتن ====================

class _MatnaCard extends StatelessWidget {
  final Matna matna;
  final PathwayInfo pathway;
  final MutunService mutunService;
  final StudentsService studentsService;

  const _MatnaCard({
    required this.matna,
    required this.pathway,
    required this.mutunService,
    required this.studentsService,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MatnaDetailScreen(
                  matna: matna,
                  pathway: pathway,
                  mutunService: mutunService,
                  studentsService: studentsService,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: matna.isNazm
                        ? AppColors.goldSurface
                        : AppColors.primarySurface,
                    borderRadius:
                        BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    matna.isNazm
                        ? Icons.format_quote_rounded
                        : Icons.article_rounded,
                    color: matna.isNazm
                        ? AppColors.gold
                        : AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(matna.name, style: textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        '${matna.typeLabel} • ${matna.totalCount} ${matna.unitLabel}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // قائمة ثلاث نقاط بدل زر الحذف المباشر
                CardActionsMenu(
                  actions: [
                    CardMenuAction(
                      label: 'حذف المتن',
                      icon: Icons.delete_outline_rounded,
                      destructive: true,
                      onTap: () => _confirmDelete(context),
                    ),
                  ],
                ),
                Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color:
                        AppColors.inkMuted.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف المتن',
      message:
          'سيتم حذف "${matna.name}" مع جميع تسجيلات حفظ الطلاب فيه.\nلا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'حذف نهائي',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final result = await mutunService.deleteMatna(matna);
    if (!context.mounted) return;

    if (result.success) {
      showSuccessSnackBar(context, 'تم حذف المتن "${matna.name}"');
    } else {
      showErrorSnackBar(context, result.errorMessage!);
    }
  }
}

// ==================== حوار إضافة متن ====================

class _AddMatnaDialog extends StatefulWidget {
  final MutunService service;
  final String teacherId;
  final PathwayInfo pathway;

  const _AddMatnaDialog({
    required this.service,
    required this.teacherId,
    required this.pathway,
  });

  @override
  State<_AddMatnaDialog> createState() => _AddMatnaDialogState();
}

class _AddMatnaDialogState extends State<_AddMatnaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _totalController = TextEditingController();

  String _type = 'nazm';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.service.addMatna(
      teacherId: widget.teacherId,
      pathwayId: widget.pathway.id,
      name: _nameController.text,
      type: _type,
      totalCount: int.parse(_totalController.text.trim()),
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.pop(context);
      showSuccessSnackBar(
          context, 'تمت إضافة المتن "${_nameController.text.trim()}"');
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isNazm = _type == 'nazm';

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.auto_stories_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إضافة متن جديد',
                              style: textTheme.titleMedium),
                          Text(widget.pathway.name,
                              style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(_errorMessage!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.error)),
                  ),
                  const SizedBox(height: 14),
                ],

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المتن *',
                    hintText: 'مثال: متن الآجرومية',
                    prefixIcon:
                        Icon(Icons.auto_stories_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'اسم المتن مطلوب'
                      : null,
                ),
                const SizedBox(height: 16),

                // نوع المتن
                Text('نوع المتن', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TypeTile(
                        label: 'نظم',
                        subtitle: 'يُحسب بالأبيات',
                        icon: Icons.format_quote_rounded,
                        selected: _type == 'nazm',
                        onTap: () =>
                            setState(() => _type = 'nazm'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TypeTile(
                        label: 'نثر',
                        subtitle: 'يُحسب بالصفحات',
                        icon: Icons.article_rounded,
                        selected: _type == 'nathr',
                        onTap: () =>
                            setState(() => _type = 'nathr'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _totalController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText:
                        isNazm ? 'عدد الأبيات الإجمالي *' : 'عدد الصفحات الإجمالي *',
                    prefixIcon: const Icon(
                        Icons.format_list_numbered_rounded),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) {
                      return 'أدخل عدداً صحيحاً أكبر من صفر';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(
                              color: AppColors.line),
                          foregroundColor: AppColors.inkSecondary,
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('إضافة المتن'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primarySurface
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.lineSoft,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected
                    ? AppColors.primary
                    : AppColors.inkMuted,
                size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected
                    ? AppColors.primaryDark
                    : AppColors.ink,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== شاشة تفاصيل المتن (تقدم الطلاب) ====================

class MatnaDetailScreen extends StatelessWidget {
  final Matna matna;
  final PathwayInfo pathway;
  final MutunService mutunService;
  final StudentsService studentsService;

  const MatnaDetailScreen({
    super.key,
    required this.matna,
    required this.pathway,
    required this.mutunService,
    required this.studentsService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(matna.name),
            Text(
              '${matna.typeLabel} • ${matna.totalCount} ${matna.unitLabel}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Student>>(
        stream: studentsService.watchPathwayStudents(
          teacherId: matna.teacherId,
          pathwayId: pathway.id,
        ),
        builder: (context, studentsSnap) {
          if (studentsSnap.hasError) {
            return ErrorState(
              message: 'حدث خطأ أثناء تحميل الطلاب',
              onRetry: () {},
            );
          }
          if (!studentsSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final students = studentsSnap.data!;
          if (students.isEmpty) {
            return const EmptyState(
              icon: Icons.school_outlined,
              title: 'لا يوجد طلاب في هذا المسار',
              message:
                  'أضف طلاباً في تبويب "الطلاب" أولاً\nلتتمكن من متابعة حفظهم',
            );
          }

          return StreamBuilder<List<MutunRecording>>(
            stream: mutunService.watchMatnaRecordings(
              teacherId: matna.teacherId,
              matnaId: matna.id,
            ),
            builder: (context, recSnap) {
              if (!recSnap.hasData) {
                return const Center(
                    child: CircularProgressIndicator());
              }

              final recordings = recSnap.data!;
              // تجميع السجلات حسب الطالب
              final byStudent = <String, List<MutunRecording>>{};
              for (final r in recordings) {
                byStudent.putIfAbsent(r.studentId, () => []).add(r);
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  final recs = byStudent[student.id] ?? [];
                  return _StudentMatnaCard(
                    student: student,
                    matna: matna,
                    recordings: recs,
                    mutunService: mutunService,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ==================== بطاقة تقدم طالب في المتن ====================

class _StudentMatnaCard extends StatelessWidget {
  final Student student;
  final Matna matna;
  final List<MutunRecording> recordings;
  final MutunService mutunService;

  const _StudentMatnaCard({
    required this.student,
    required this.matna,
    required this.recordings,
    required this.mutunService,
  });

  /// آخر نقطة وصل إليها الطالب (أكبر "إلى")
  double get _lastReached =>
      recordings.fold(0.0, (max, r) => r.to > max ? r.to : max);

  double get _progress => matna.totalCount > 0
      ? (_lastReached / matna.totalCount).clamp(0.0, 1.0)
      : 0;

  bool get _completed => _lastReached >= matna.totalCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: _completed ? AppColors.goldSoft : AppColors.lineSoft,
          width: _completed ? 1.4 : 1,
        ),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: InitialAvatar(name: student.name, radius: 22),
        title: Text(student.name, style: textTheme.titleSmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 7,
                  backgroundColor: AppColors.lineSoft,
                  valueColor: AlwaysStoppedAnimation(
                    _completed ? AppColors.gold : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _completed
                    ? 'أتمّ المتن كاملاً 🎉'
                    : recordings.isEmpty
                        ? 'لم يبدأ بعد'
                        : 'وصل إلى ${matna.unitLabel} ${fmtNum(_lastReached)} من ${matna.totalCount} (${(_progress * 100).round()}%)',
                style: textTheme.bodySmall?.copyWith(
                  color: _completed
                      ? AppColors.goldDark
                      : AppColors.inkSecondary,
                  fontWeight:
                      _completed ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // زر تسجيل حفظ جديد
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  onPressed: recordings.isEmpty || !_completed
                      ? () => _showAddRecordingDialog(context)
                      : null,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(
                    _completed
                        ? 'المتن مكتمل الحفظ'
                        : 'تسجيل حفظ جديد',
                  ),
                ),

                if (recordings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...recordings.map(
                    (r) => _RecordingTile(
                      recording: r,
                      unitLabel: matna.unitLabel,
                      onDelete: () => _deleteRecording(context, r),
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'لا توجد تسجيلات حفظ لهذا الطالب بعد',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRecordingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AddMutunRecordingDialog(
        matna: matna,
        student: student,
        service: mutunService,
        suggestedFrom: _lastReached + 1,
      ),
    );
  }

  Future<void> _deleteRecording(
      BuildContext context, MutunRecording r) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف التسجيل',
      message:
          'سيتم حذف تسجيل ${r.weekday} (${fmtNum(r.count)} ${matna.unitLabel}).\nهل أنت متأكد؟',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final result = await mutunService.deleteRecording(r.id);
    if (!context.mounted) return;

    if (result.success) {
      showSuccessSnackBar(context, 'تم حذف التسجيل');
    } else {
      showErrorSnackBar(context, result.errorMessage!);
    }
  }
}

// ==================== بلاطة تسجيل حفظ ====================

class _RecordingTile extends StatelessWidget {
  final MutunRecording recording;
  final String unitLabel;
  final VoidCallback onDelete;

  const _RecordingTile({
    required this.recording,
    required this.unitLabel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateText =
        DateFormat('d MMMM y', 'ar').format(recording.date);
    final isAbsent = recording.isAbsent;
    final isNotListened = recording.isNotListened;
    final flagged = isAbsent || isNotListened;
    final flagColor = isAbsent ? AppColors.error : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isAbsent
            ? AppColors.errorSurface
            : isNotListened
                ? AppColors.warningSurface
                : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${recording.weekday}، $dateText',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                if (flagged) ...[
                  Row(
                    children: [
                      Icon(
                        isAbsent
                            ? Icons.event_busy_rounded
                            : Icons.hearing_disabled_rounded,
                        size: 16,
                        color: flagColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        recording.statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: flagColor,
                        ),
                      ),
                    ],
                  ),
                ] else
                  Text(
                    'من ${fmtNum(recording.from)} إلى ${fmtNum(recording.to)} (${fmtNum(recording.count)} $unitLabel)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                if (recording.notes != null &&
                    recording.notes!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    recording.notes!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // قائمة ثلاث نقاط بدل زر الحذف المباشر
          CardActionsMenu(
            actions: [
              CardMenuAction(
                label: 'حذف التسجيل',
                icon: Icons.delete_outline_rounded,
                destructive: true,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== حوار تسجيل حفظ ====================

class _AddMutunRecordingDialog extends StatefulWidget {
  final Matna matna;
  final Student student;
  final MutunService service;
  final double suggestedFrom;

  const _AddMutunRecordingDialog({
    required this.matna,
    required this.student,
    required this.service,
    required this.suggestedFrom,
  });

  @override
  State<_AddMutunRecordingDialog> createState() =>
      _AddMutunRecordingDialogState();
}

class _AddMutunRecordingDialogState
    extends State<_AddMutunRecordingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  /// null = لم يُختر بعد (البيانات عائمة) | 'present' | 'absent'
  String? _attendanceStatus;

  /// البيانات قابلة للتعبئة فقط في وضع "حاضر"
  bool get _dataEnabled => _attendanceStatus == 'present';

  /// التاريخ يُفعَّل بعد اختيار أي حالة (حضور أو غياب)
  bool get _dateEnabled => _attendanceStatus != null;

  @override
  void initState() {
    super.initState();
    if (widget.suggestedFrom <= widget.matna.totalCount) {
      _fromController.text = fmtNum(widget.suggestedFrom);
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? get _autoCount {
    final from = double.tryParse(_fromController.text.trim());
    final to = double.tryParse(_toController.text.trim());
    if (from == null || to == null || to < from) return null;
    return to - from + 1;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (_attendanceStatus == null) {
      setState(() => _errorMessage =
          'اختر حالة الطالب أولاً: حاضر أو غائب');
      return;
    }

    // وضع "غائب": لا بيانات — يُحفظ الغياب مباشرة
    if (_attendanceStatus == 'absent') {
      await _saveRecording(status: 'absent');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final from = double.parse(_fromController.text.trim());
    final to = double.parse(_toController.text.trim());

    if (to > widget.matna.totalCount) {
      setState(() => _errorMessage =
          'القيمة "إلى" ($to) تتجاوز إجمالي المتن (${widget.matna.totalCount})');
      return;
    }

    await _saveRecording(status: 'present', from: from, to: to);
  }

  Future<void> _saveRecording({
    required String status,
    double? from,
    double? to,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // في وضع الغياب لا تُحفظ ملاحظات الحفظ
    final notesText = status == 'absent' ? null : _notesController.text;

    final result = await widget.service.addRecording(
      matna: widget.matna,
      studentId: widget.student.id,
      date: _selectedDate,
      from: from ?? 0,
      to: to ?? 0,
      notes: notesText,
      status: status,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.pop(context);
      showSuccessSnackBar(
        context,
        status == 'absent'
            ? 'تم تسجيل غياب ${widget.student.name}'
            : 'تم تسجيل حفظ ${widget.student.name}',
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final weekday = MutunService.weekdayOf(_selectedDate);
    final dateText =
        DateFormat('d MMMM y', 'ar').format(_selectedDate);
    final count = _autoCount;
    final isAbsentMode = _attendanceStatus == 'absent';

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.bookmark_added_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('تسجيل حفظ',
                              style: textTheme.titleMedium),
                          Text(
                            '${widget.student.name} • ${widget.matna.name}',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ==== زرا الحضور/الغياب — أعلى البطاقة ====
                Row(
                  children: [
                    Expanded(
                      child: _AttendanceButton(
                        label: 'حاضر',
                        icon: Icons.check_circle_outline_rounded,
                        selected: _attendanceStatus == 'present',
                        enabled: !_isLoading,
                        color: AppColors.primary,
                        surfaceColor: AppColors.primarySurface,
                        onTap: () => setState(() {
                          _attendanceStatus = 'present';
                          _errorMessage = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AttendanceButton(
                        label: 'غائب',
                        icon: Icons.event_busy_rounded,
                        selected: isAbsentMode,
                        enabled: !_isLoading,
                        color: AppColors.error,
                        surfaceColor: AppColors.errorSurface,
                        onTap: () => setState(() {
                          _attendanceStatus = 'absent';
                          _errorMessage = null;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_attendanceStatus == null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.touch_app_rounded,
                            size: 18, color: AppColors.inkMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'البيانات معطّلة — اختر حالة الطالب (حاضر / غائب) أولاً',
                            style: textTheme.bodySmall
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (isAbsentMode) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_busy_rounded,
                            size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'سيُسجَّل ${widget.student.name} غائباً في التاريخ المحدد أدناه',
                            style: textTheme.bodySmall
                                ?.copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(_errorMessage!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.error)),
                  ),
                  const SizedBox(height: 14),
                ],

                // التاريخ (يحدد اليوم تلقائياً)
                InkWell(
                  onTap: _dateEnabled ? _pickDate : null,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'التاريخ',
                      prefixIcon:
                          const Icon(Icons.calendar_month_rounded),
                      enabled: _dateEnabled,
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$weekday، $dateText',
                          style: _dateEnabled
                              ? null
                              : const TextStyle(
                                  color: AppColors.inkMuted),
                        ),
                        if (_dateEnabled)
                          const Icon(Icons.edit_calendar_outlined,
                              size: 18, color: AppColors.inkMuted),
                      ],
                    ),
                  ),
                ),

                // حقول المقدار والملاحظات — تُخفى في وضع "غائب"
                if (!isAbsentMode) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _fromController,
                          enabled: _dataEnabled,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: InputDecoration(
                            labelText:
                                'من (${widget.matna.unitLabel}) *',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final n =
                                double.tryParse(v?.trim() ?? '');
                            if (n == null || n < 1) {
                              return 'أدخل رقماً صحيحاً';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _toController,
                          enabled: _dataEnabled,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: InputDecoration(
                            labelText:
                                'إلى (${widget.matna.unitLabel}) *',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final n =
                                double.tryParse(v?.trim() ?? '');
                            if (n == null || n < 1) {
                              return 'أدخل رقماً صحيحاً';
                            }
                            final from = double.tryParse(
                                _fromController.text.trim());
                            if (from != null && n < from) {
                              return 'أقل من "من"';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  if (_dataEnabled && count != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'المقدار: $count ${widget.matna.unitLabel} (محسوب تلقائياً)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _notesController,
                    enabled: _dataEnabled,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      prefixIcon: Icon(Icons.notes_rounded),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(
                              color: AppColors.line),
                          foregroundColor: AppColors.inkSecondary,
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(isAbsentMode
                                ? 'حفظ الغياب'
                                : 'حفظ التسجيل'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// زر اختيار الحضور/الغياب أعلى حوار تسجيل الحفظ
class _AttendanceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final Color color;
  final Color surfaceColor;
  final VoidCallback onTap;

  const _AttendanceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.color,
    required this.surfaceColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? surfaceColor : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? color : AppColors.lineSoft,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 20,
                color: selected ? color : AppColors.inkMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? color : AppColors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
