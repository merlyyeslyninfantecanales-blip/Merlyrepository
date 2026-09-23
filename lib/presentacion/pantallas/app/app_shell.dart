import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../main.dart';
import '../../../datos/local_data_service.dart';
import '../../../datos/pdf_report_service.dart';
import '../../../datos/supabase_database_service.dart';

const _currentAppVersionCode = int.fromEnvironment(
  'APP_VERSION_CODE',
  defaultValue: 5,
);

enum AppModule {
  overview,
  practices,
  students,
  companies,
  coordinators,
  vacancies,
  attendance,
  tracking,
  evaluation,
  reports,
  closure,
  users,
}

extension AppModuleInfo on AppModule {
  String get title => switch (this) {
    AppModule.overview => 'Inicio',
    AppModule.practices => 'Prácticas',
    AppModule.students => 'Estudiantes',
    AppModule.companies => 'Empresas',
    AppModule.coordinators => 'Encargados',
    AppModule.vacancies => 'Vacantes',
    AppModule.attendance => 'Registro',
    AppModule.tracking => 'Seguimiento',
    AppModule.evaluation => 'Evaluaciones',
    AppModule.reports => 'Reportes',
    AppModule.closure => 'Cierre',
    AppModule.users => 'Usuarios',
  };

  IconData get icon => switch (this) {
    AppModule.overview => Icons.dashboard_rounded,
    AppModule.practices => Icons.description_rounded,
    AppModule.students => Icons.groups_rounded,
    AppModule.companies => Icons.apartment_rounded,
    AppModule.coordinators => Icons.badge_rounded,
    AppModule.vacancies => Icons.work_rounded,
    AppModule.attendance => Icons.fact_check_rounded,
    AppModule.tracking => Icons.trending_up_rounded,
    AppModule.evaluation => Icons.star_rounded,
    AppModule.reports => Icons.bar_chart_rounded,
    AppModule.closure => Icons.task_alt_rounded,
    AppModule.users => Icons.manage_accounts_rounded,
  };
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppModule _current = AppModule.overview;
  final List<AppModule> _moduleHistory = [];
  final data = LocalDataService.instance;
  final remote = SupabaseDatabaseService.instance;
  bool _loadedRemoteData = false;
  bool _updateCheckStarted = false;
  bool _updateDialogShown = false;
  AppUpdateInfo? _availableUpdate;

  AppUser get user => SessionController.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _loadRemoteData();
  }

  Future<void> _loadRemoteData() async {
    if (!remote.isReady || _loadedRemoteData) return;
    try {
      final students = await remote.loadStudents();
      final companies = await remote.loadCompanies();
      final practices = await remote.loadPractices();
      final attendance = await remote.loadAllAttendanceRecords();
      final evaluations = await remote.loadAllEvaluations();
      final tracking = await remote.loadAllTrackingRecords();
      final vacancies = await remote.loadVacancies();
      final users = await remote.loadUsers();
      if (!mounted) return;
      setState(() {
        data.replaceStudents(students);
        data.replaceCompanies(companies);
        data.replacePractices(practices);
        data.replaceAttendanceRecords(attendance);
        data.replaceEvaluations(evaluations);
        data.replaceTrackingRecords(tracking);
        data.replaceVacancies(vacancies);
        data.replaceUsers(users);
        _loadedRemoteData = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadedRemoteData = true);
      } else {
        _loadedRemoteData = true;
      }
    }
    await _checkForAppUpdate();
  }

  Future<void> _checkForAppUpdate() async {
    if (!remote.isReady || _updateCheckStarted) return;
    _updateCheckStarted = true;
    try {
      final latest = await remote.loadLatestAppUpdate();
      if (latest == null) return;
      if (latest.versionCode <= _currentAppVersionCode) return;
      if (!mounted) return;
      setState(() => _availableUpdate = latest);
      if (_updateDialogShown) return;
      _updateDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showUpdateDialog(latest);
      });
    } catch (_) {}
  }

  void _showUpdateDialog(AppUpdateInfo update) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva actualizacion disponible'),
        content: Text(
          [
            'Version ${update.versionName}',
            if (update.notes.trim().isNotEmpty) update.notes.trim(),
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mas tarde'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openUpdate(update);
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Descargar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUpdate(AppUpdateInfo update) async {
    final rawUrl = update.apkUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) {
      _toast(context, 'La actualizacion aun no tiene enlace de descarga.');
      return;
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      _toast(context, 'El enlace de descarga no es valido.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _toast(context, 'No se pudo abrir el enlace de descarga.');
    }
  }

  List<AppModule> get modules => switch (user.role) {
    UserRole.supervisor => const [
      AppModule.overview,
      AppModule.practices,
      AppModule.students,
      AppModule.companies,
      AppModule.coordinators,
      AppModule.vacancies,
      AppModule.attendance,
      AppModule.tracking,
      AppModule.evaluation,
      AppModule.reports,
      AppModule.closure,
      AppModule.users,
    ],
    UserRole.encargado => const [
      AppModule.overview,
      AppModule.attendance,
      AppModule.tracking,
      AppModule.reports,
      AppModule.practices,
    ],
    UserRole.estudiante => const [
      AppModule.overview,
      AppModule.attendance,
      AppModule.tracking,
    ],
    UserRole.empresa => const [AppModule.overview],
  };

  @override
  Widget build(BuildContext context) {
    if (!SessionController.instance.isLoggedIn) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (!modules.contains(_current)) _current = AppModule.overview;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 450) _goBack();
        },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _Header(
                  user: user,
                  module: _current,
                  canGoBack: _current != AppModule.overview,
                  onBack: _goBack,
                  onLogout: _logout,
                  onReport: _reportCurrent,
                  updateInfo: _availableUpdate,
                  onOpenUpdate: _openUpdate,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(.035, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: slide,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: .985,
                              end: 1,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: _body(),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _BottomNav(
            modules: modules,
            current: _current,
            onTap: _openModule,
            onLogout: _logout,
          ),
          floatingActionButton: _canCreate
              ? FloatingActionButton.extended(
                  onPressed: _createCurrent,
                  icon: const Icon(Icons.add),
                  label: Text(
                    _current == AppModule.evaluation
                        ? 'Nueva evaluación'
                        : _current == AppModule.tracking
                        ? 'Nuevo seguimiento'
                        : _current == AppModule.vacancies
                        ? 'Nueva vacante'
                        : 'Nuevo',
                  ),
                )
              : null,
        ),
      ),
    );
  }

  void _openModule(AppModule module) {
    if (module == _current) return;
    setState(() {
      _moduleHistory.add(_current);
      _current = module;
    });
  }

  void _goBack() {
    if (_current == AppModule.overview) {
      _logout();
      return;
    }
    setState(() {
      while (_moduleHistory.isNotEmpty) {
        final previous = _moduleHistory.removeLast();
        if (modules.contains(previous) && previous != _current) {
          _current = previous;
          return;
        }
      }
      _current = AppModule.overview;
    });
  }

  bool get _canCreate {
    return user.role == UserRole.supervisor &&
        const {
          AppModule.practices,
          AppModule.students,
          AppModule.companies,
          AppModule.coordinators,
          AppModule.tracking,
          AppModule.evaluation,
          AppModule.users,
        }.contains(_current);
  }

  Widget _body() => switch (_current) {
    AppModule.overview => _Overview(user: user, onOpen: _openModule),
    AppModule.practices => _PracticesPage(
      user: user,
      refresh: () => setState(() {}),
    ),
    AppModule.students => _StudentsPage(refresh: () => setState(() {})),
    AppModule.companies => _CompaniesPage(refresh: () => setState(() {})),
    AppModule.coordinators => _CoordinatorsPage(refresh: () => setState(() {})),
    AppModule.vacancies => _VacanciesPage(user: user),
    AppModule.attendance => _AttendancePage(user: user),
    AppModule.tracking => _TrackingPage(user: user),
    AppModule.evaluation => _EvaluationPage(user: user),
    AppModule.reports => _ReportsPage(user: user),
    AppModule.closure => _ClosurePage(refresh: () => setState(() {})),
    AppModule.users => _UsersPage(refresh: () => setState(() {})),
  };

  Future<void> _logout() async {
    await SupabaseDatabaseService.instance.signOut();
    SessionController.instance.logout();
  }

  void _createCurrent() {
    switch (_current) {
      case AppModule.practices:
        _openPracticeForm();
        break;
      case AppModule.students:
        _openStudentForm();
        break;
      case AppModule.companies:
        _openCompanyForm();
        break;
      case AppModule.coordinators:
        _openUserForm(null, UserRole.encargado);
        break;
      case AppModule.evaluation:
        _openEvaluationForm();
        break;
      case AppModule.tracking:
        _openTrackingForm();
        break;
      case AppModule.users:
        _openUserForm();
        break;
      default:
        break;
    }
  }

  Future<void> _reportCurrent() async {
    final lines = _linesFor(_current);
    await PdfReportService.createAndSaveReport(
      fileName: 'practicapp_${_current.title}',
      title: 'Reporte de ${_current.title}',
      lines: lines,
    );
    if (mounted) _toast(context, 'PDF guardado o listo para compartir.');
  }

  List<String> _linesFor(AppModule module) => switch (module) {
    AppModule.students =>
      data
          .getStudents()
          .map((s) => '${s.code} - ${s.name} - ${s.program}')
          .toList(),
    AppModule.companies =>
      data
          .getCompanies()
          .map(
            (c) => '${c.ruc} - ${c.name} - GPS ${c.latitude}, ${c.longitude}',
          )
          .toList(),
    AppModule.coordinators => data.getUsersByRole(UserRole.encargado).map((u) {
      Company? company;
      for (final item in data.getCompanies()) {
        if (item.id == u.companyId) {
          company = item;
          break;
        }
      }
      return '${u.name} - ${u.email} - Empresa: ${company?.name ?? 'Sin asignar'}';
    }).toList(),
    AppModule.vacancies =>
      data
          .getCompanies()
          .map(
            (c) =>
                '${c.name} - ${c.ruc} - Vacantes disponibles: ${c.totalVacancies}',
          )
          .toList(),
    AppModule.attendance =>
      data
          .getPractices()
          .expand(
            (p) => data
                .getAttendances(p.id)
                .map(
                  (a) =>
                      '${p.student.name} - ${_date(a.date)} - ${a.status.label} - ${a.hours}h',
                ),
          )
          .toList(),
    AppModule.evaluation =>
      data
          .getPractices()
          .expand(
            (p) => data
                .getEvaluations(p.id)
                .map((e) => '${p.student.name} - ${e.title} - ${e.score}/100'),
          )
          .toList(),
    AppModule.users =>
      data
          .getUsers()
          .map((u) => '${u.name} - ${u.role.label} - ${u.email}')
          .toList(),
    _ =>
      data
          .getPractices()
          .map(
            (p) =>
                '${p.student.name} - ${p.company.name} - ${(p.progress * 100).round()}%',
          )
          .toList(),
  };

  Future<void> _openPracticeForm([Practice? practice]) async {
    final result = await showModalBottomSheet<_PracticeFormData>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: _sheetShape,
      builder: (_) => _PracticeForm(initial: practice),
    );
    if (result == null) return;
    if (practice == null) {
      final created = data.addPractice(
        student: result.student,
        company: result.company,
        practiceModule: result.practiceModule,
        shift: result.shift,
        startDate: result.startDate,
        endDate: result.startDate,
        requiredHours: result.requiredHours,
        status: PracticeStatus.active,
        learningObjective: result.learningObjective,
      );
      await _saveRemotePractice(created);
    } else {
      practice
        ..student = result.student
        ..company = result.company
        ..practiceModule = result.practiceModule
        ..shift = result.shift
        ..startDate = result.startDate
        ..requiredHours = result.requiredHours
        ..learningObjective = result.learningObjective;
      data.updatePractice(practice);
      await _saveRemotePractice(practice);
    }
    setState(() {});
  }

  Future<void> _saveRemotePractice(Practice practice) async {
    if (!remote.isReady) return;
    try {
      await remote.savePractice(practice);
      if (mounted) _toast(context, 'Práctica guardada en Supabase.');
    } catch (_) {
      if (mounted)
        _toast(context, 'No se pudo guardar la práctica en Supabase.');
    }
  }

  Future<void> _openStudentForm([Student? student]) async {
    final result = await showModalBottomSheet<Student>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: _sheetShape,
      builder: (_) => _StudentForm(initial: student),
    );
    if (result == null) return;
    if (student == null) {
      final created = data.addStudent(
        name: result.name,
        code: result.code,
        phone: result.phone,
        program: result.program,
        semester: result.semester,
      );
      await _saveRemoteStudent(created);
    } else {
      student
        ..name = result.name
        ..code = result.code
        ..phone = result.phone
        ..program = result.program
        ..semester = result.semester;
      data.updateStudent(student);
      await _saveRemoteStudent(student);
    }
    setState(() {});
  }

  Future<void> _saveRemoteStudent(Student student) async {
    if (!remote.isReady) return;
    try {
      final saved = await remote.saveStudent(student);
      student
        ..id = saved.id
        ..email = saved.email
        ..semester = saved.semester;
      if (mounted) _toast(context, 'Estudiante guardado en Supabase.');
    } catch (_) {
      if (mounted)
        _toast(context, 'No se pudo guardar el estudiante en Supabase.');
    }
  }

  Future<void> _openCompanyForm([Company? company]) async {
    final result = await showModalBottomSheet<Company>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: _sheetShape,
      builder: (_) => _CompanyForm(initial: company),
    );
    if (result == null) return;
    if (company == null) {
      final created = data.addCompany(
        name: result.name,
        ruc: result.ruc,
        phone: result.phone,
        address: result.address,
        contact: result.contact,
        email: result.email,
        latitude: result.latitude,
        longitude: result.longitude,
        totalVacancies: result.totalVacancies,
      );
      await _saveRemoteCompany(created);
    } else {
      company
        ..name = result.name
        ..ruc = result.ruc
        ..phone = result.phone
        ..address = result.address
        ..contact = result.contact
        ..email = result.email
        ..latitude = result.latitude
        ..longitude = result.longitude
        ..totalVacancies = result.totalVacancies;
      data.updateCompany(company);
      await _saveRemoteCompany(company);
    }
    setState(() {});
  }

  Future<void> _saveRemoteCompany(Company company) async {
    if (!remote.isReady) return;
    try {
      final saved = await remote.saveCompany(company);
      company.id = saved.id;
      if (mounted) _toast(context, 'Empresa guardada en Supabase.');
    } catch (_) {
      if (mounted)
        _toast(context, 'No se pudo guardar la empresa en Supabase.');
    }
  }

  Future<void> _openEvaluationForm([Evaluation? evaluation]) async {
    final result = await showModalBottomSheet<_EvaluationFormData>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: _sheetShape,
      builder: (_) => _EvaluationForm(initial: evaluation),
    );
    if (result == null) return;
    Evaluation target;
    if (evaluation == null) {
      target = data.addEvaluation(
        practiceId: result.practice.id,
        title: result.title,
        score: result.score,
        comment: result.comment,
        performance: result.performance,
        pdfName: result.pdfName,
      );
    } else {
      target = evaluation
        ..practiceId = result.practice.id
        ..title = result.title
        ..score = result.score
        ..comment = result.comment
        ..performance = result.performance
        ..pdfName = result.pdfName;
      data.updateEvaluation(evaluation);
    }
    await _saveRemoteEvaluation(target);
    setState(() {});
  }

  Future<void> _saveRemoteEvaluation(Evaluation evaluation) async {
    if (!remote.isReady) return;
    try {
      await remote.saveEvaluation(evaluation);
      if (mounted) _toast(context, 'Evaluación guardada en Supabase.');
    } catch (_) {
      if (mounted)
        _toast(context, 'No se pudo guardar la evaluación en Supabase.');
    }
  }

  Future<void> _openTrackingForm([TrackingRecord? record]) async {
    final result = await showModalBottomSheet<TrackingRecord>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: _sheetShape,
      builder: (_) => _TrackingForm(initial: record),
    );
    if (result == null) return;
    TrackingRecord target;
    if (record == null) {
      target = data.addTrackingRecord(
        practiceId: result.practiceId,
        title: result.title,
        progress: result.progress,
        completedObjectives: result.completedObjectives,
        pendingObjectives: result.pendingObjectives,
        monthlyReport: result.monthlyReport,
        pdfName: result.pdfName,
      );
    } else {
      target = record
        ..practiceId = result.practiceId
        ..title = result.title
        ..progress = result.progress
        ..completedObjectives = result.completedObjectives
        ..pendingObjectives = result.pendingObjectives
        ..monthlyReport = result.monthlyReport
        ..pdfName = result.pdfName;
      data.updateTrackingRecord(record);
    }
    await _saveRemoteTracking(target);
    setState(() {});
  }

  Future<void> _saveRemoteTracking(TrackingRecord record) async {
    if (!remote.isReady) return;
    try {
      await remote.saveTrackingRecord(record);
      if (mounted) _toast(context, 'Seguimiento guardado en Supabase.');
    } catch (_) {
      if (mounted)
        _toast(context, 'No se pudo guardar el seguimiento en Supabase.');
    }
  }

  Future<void> _openUserForm([AppUser? appUser, UserRole? forcedRole]) async {
    final result = await showModalBottomSheet<AppUser>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: _sheetShape,
      builder: (_) => _UserForm(initial: appUser, forcedRole: forcedRole),
    );
    if (result == null) return;
    AppUser target;
    if (appUser == null) {
      target = data.addUser(
        name: result.name,
        email: result.email,
        role: result.role,
        password: result.password,
        companyId: result.companyId,
        studentId: result.studentId,
      );
      await _createRemoteUser(target);
    } else {
      target = appUser
        ..name = result.name
        ..email = result.email
        ..role = result.role
        ..password = result.password
        ..companyId = result.companyId
        ..studentId = result.studentId;
      data.updateUser(appUser);
      await _updateRemoteUser(target);
    }
    setState(() {});
  }

  Future<void> _createRemoteUser(AppUser user) async {
    if (!remote.isReady) return;
    try {
      final saved = await remote.adminCreateUser(user);
      user
        ..id = saved.id
        ..avatar = saved.avatar
        ..companyId = saved.companyId
        ..studentId = saved.studentId
        ..authUserId = saved.authUserId;
      if (mounted) {
        _toast(context, 'Usuario Auth y perfil creados en Supabase.');
      }
    } catch (error) {
      if (mounted) {
        _toast(context, 'No se pudo crear el usuario: ${error.toString()}');
      }
    }
  }

  Future<void> _updateRemoteUser(AppUser user) async {
    if (!remote.isReady) return;
    try {
      final saved = await remote.adminUpdateUser(user);
      user
        ..id = saved.id
        ..avatar = saved.avatar
        ..companyId = saved.companyId
        ..studentId = saved.studentId
        ..authUserId = saved.authUserId;
      if (mounted) _toast(context, 'Usuario actualizado en Supabase.');
    } catch (error) {
      if (mounted)
        _toast(
          context,
          'No se pudo actualizar el usuario: ${error.toString()}',
        );
    }
  }
}

final _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(28),
);

class _Header extends StatelessWidget {
  final AppUser user;
  final AppModule module;
  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onLogout;
  final VoidCallback onReport;
  final AppUpdateInfo? updateInfo;
  final ValueChanged<AppUpdateInfo> onOpenUpdate;
  const _Header({
    required this.user,
    required this.module,
    required this.canGoBack,
    required this.onBack,
    required this.onLogout,
    required this.onReport,
    required this.updateInfo,
    required this.onOpenUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 370;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.fromLTRB(compact ? 10 : 16, 8, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              if (canGoBack)
                IconButton(
                  tooltip: 'Volver',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
              Container(
                width: compact ? 38 : 42,
                height: compact ? 38 : 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D28D9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PracticApp',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      module.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showNotifications(
                  context,
                  user,
                  updateInfo: updateInfo,
                  onOpenUpdate: onOpenUpdate,
                ),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_rounded),
                    if (updateInfo != null)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 1.5,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                color: const Color(0xFF4F46E5),
              ),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.instance.mode,
                builder: (context, mode, _) {
                  return PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'pdf') {
                        onReport();
                      } else if (v == 'theme') {
                        ThemeController.instance.toggle();
                      } else {
                        onLogout();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'pdf', child: Text('Exportar PDF')),
                      PopupMenuItem(
                        value: 'theme',
                        child: Text('Cambiar tema'),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: Text('Cerrar sesión'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          Row(
            children: [
              _Avatar(user: user),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _Pill(user.role.label, user.role.color),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final List<AppModule> modules;
  final AppModule current;
  final ValueChanged<AppModule> onTap;
  final VoidCallback onLogout;
  const _BottomNav({
    required this.modules,
    required this.current,
    required this.onTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final primary = modules.take(4).toList();
    final more = modules.skip(4).toList();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 7),
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          children: [
            ...primary.map(
              (m) => _NavItem(
                module: m,
                selected: m == current,
                onTap: () => onTap(m),
              ),
            ),
            _MoreNav(
              more: more,
              current: current,
              onTap: onTap,
              onLogout: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final AppModule module;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.module,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _PressableScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: selected ? 12 : 0,
                  vertical: selected ? 5 : 0,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF4F46E5).withValues(alpha: .12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  module.icon,
                  color: selected
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                module.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreNav extends StatelessWidget {
  final List<AppModule> more;
  final AppModule current;
  final ValueChanged<AppModule> onTap;
  final VoidCallback onLogout;
  const _MoreNav({
    required this.more,
    required this.current,
    required this.onTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _PressableScale(
        onTap: () => showModalBottomSheet(
          context: context,
          useSafeArea: true,
          shape: _sheetShape,
          builder: (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: more
                        .map(
                          (m) => ActionChip(
                            label: Text(m.title),
                            avatar: Icon(m.icon),
                            onPressed: () {
                              Navigator.pop(context);
                              onTap(m);
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onLogout();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: more.contains(current) ? 12 : 0,
                  vertical: more.contains(current) ? 5 : 0,
                ),
                decoration: BoxDecoration(
                  color: more.contains(current)
                      ? const Color(0xFF4F46E5).withValues(alpha: .12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.more_horiz,
                  color: more.contains(current)
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Más',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: more.contains(current)
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeSelector extends StatelessWidget {
  final Practice? selected;
  final List<Practice> practices;
  final String label;
  final ValueChanged<Practice> onSelected;

  const _PracticeSelector({
    required this.selected,
    required this.practices,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: practices.isEmpty ? null : () => _openSheet(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.person_search),
          suffixIcon: const Icon(Icons.keyboard_arrow_down),
        ),
        child: Text(
          selected == null
              ? 'Toca para seleccionar'
              : '${selected!.student.name} - ${selected!.company.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected == null
                ? const Color(0xFF6B7280)
                : const Color(0xFF111827),
            fontWeight: selected == null ? FontWeight.w500 : FontWeight.w800,
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: _sheetShape,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: practices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final practice = practices[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(practice.student.name.substring(0, 1)),
                        ),
                        title: Text(
                          practice.student.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${practice.student.code} - ${practice.company.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: practice == selected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF4F46E5),
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          onSelected(practice);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _showNotifications(
  BuildContext context,
  AppUser user, {
  AppUpdateInfo? updateInfo,
  required ValueChanged<AppUpdateInfo> onOpenUpdate,
}) {
  final data = LocalDataService.instance;
  final practices = data.getPracticesForUser(user);
  final completed = practices
      .where((p) => p.status == PracticeStatus.completed)
      .length;
  final pendingClosures = practices
      .where((p) => _ClosureValidation.from(p).ready && !p.certificateIssued)
      .length;
  final active = practices
      .where((p) => p.status == PracticeStatus.active)
      .length;
  final update = updateInfo;

  final items = <_NotificationItem>[
    if (update != null)
      _NotificationItem(
        icon: Icons.system_update_alt_rounded,
        title: 'Nueva version ${update.versionName}',
        detail: update.notes.trim().isEmpty
            ? 'Hay una actualizacion disponible para descargar.'
            : update.notes.trim(),
        color: const Color(0xFFDC2626),
        actionLabel: 'Descargar APK',
        onAction: () {
          Navigator.pop(context);
          onOpenUpdate(update);
        },
      ),
    _NotificationItem(
      icon: Icons.work_history,
      title: '$active prácticas activas',
      detail: 'Revisa el avance y las horas acumuladas.',
      color: const Color(0xFF2563EB),
    ),
    _NotificationItem(
      icon: Icons.task_alt,
      title: '$pendingClosures listas para cierre',
      detail: 'Puedes emitir certificado si cumplen requisitos.',
      color: const Color(0xFF059669),
    ),
    _NotificationItem(
      icon: Icons.verified,
      title: '$completed prácticas completadas',
      detail: 'Incluidas en reportes y cierre de prácticas.',
      color: const Color(0xFF7C3AED),
    ),
  ];

  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    shape: _sheetShape,
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.notifications_rounded,
                    color: Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Notificaciones',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: item.color.withOpacity(.12),
                    foregroundColor: item.color,
                    child: Icon(item.icon),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(item.detail),
                  trailing: item.actionLabel == null
                      ? null
                      : TextButton(
                          onPressed: item.onAction,
                          child: Text(item.actionLabel!),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _NotificationItem {
  final IconData icon;
  final String title;
  final String detail;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
    this.actionLabel,
    this.onAction,
  });
}

class _Overview extends StatelessWidget {
  final AppUser user;
  final ValueChanged<AppModule> onOpen;
  const _Overview({required this.user, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final data = LocalDataService.instance;
    final practices = data.getPracticesForUser(user);
    final isStudent = user.role == UserRole.estudiante;
    final isCoordinator = user.role == UserRole.encargado;
    final coordinatorCompany = isCoordinator
        ? data.getCompanyForUser(user)
        : null;
    final totalCompanyVacancies = data.getCompanies().fold<int>(
      0,
      (sum, company) => sum + company.totalVacancies,
    );
    final stats = isStudent
        ? [
            _Stat(
              'Empresas',
              '${data.getCompanies().length}',
              Icons.business,
              const Color(0xFF7C3AED),
              onTap: () => _showOverviewList(
                context,
                'Empresas disponibles',
                data
                    .getCompanies()
                    .map((c) => '${c.name}\n${c.address}')
                    .toList(),
              ),
            ),
            _Stat(
              'Completadas',
              '${practices.where((p) => p.status == PracticeStatus.completed).length}',
              Icons.verified,
              const Color(0xFF059669),
              onTap: () => _showOverviewList(
                context,
                'Prácticas completadas',
                practices
                    .where((p) => p.status == PracticeStatus.completed)
                    .map(
                      (p) => '${p.company.name}\n${p.accumulatedHours} horas',
                    )
                    .toList(),
              ),
            ),
            _Stat(
              'Vacantes',
              '$totalCompanyVacancies',
              Icons.trending_up,
              const Color(0xFFF97316),
              onTap: () => _showOverviewList(
                context,
                'Vacantes disponibles',
                data
                    .getCompanies()
                    .map((c) => '${c.name}\n${c.totalVacancies} disponibles')
                    .toList(),
              ),
            ),
          ]
        : [
            _Stat(
              'Prácticas',
              '${practices.length}',
              Icons.work_history,
              const Color(0xFF2563EB),
              onTap: () => onOpen(AppModule.practices),
            ),
            _Stat(
              'Empresas',
              '${data.getCompanies().length}',
              Icons.business,
              const Color(0xFF7C3AED),
              onTap: () => onOpen(AppModule.companies),
            ),
            _Stat(
              'Completadas',
              '${data.getPractices().where((p) => p.status == PracticeStatus.completed).length}',
              Icons.verified,
              const Color(0xFF059669),
              onTap: () => onOpen(AppModule.closure),
            ),
            _Stat(
              'Vacantes',
              '$totalCompanyVacancies',
              Icons.trending_up,
              const Color(0xFFF97316),
              onTap: () => onOpen(AppModule.vacancies),
            ),
          ];
    return _Page(
      children: [
        _Welcome(user: user),
        const SizedBox(height: 14),
        if (isCoordinator)
          _Card(
            title: 'Empresa asignada',
            icon: Icons.apartment_rounded,
            child: coordinatorCompany == null
                ? const Text('No hay empresa asignada para este encargado.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coordinatorCompany.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(coordinatorCompany.address),
                      Text('Contacto: ${coordinatorCompany.contact}'),
                      Text('Prácticas visibles: ${practices.length}'),
                    ],
                  ),
          )
        else
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width < 360 ? 1 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: stats,
          ),
        _Card(
          title: user.role == UserRole.estudiante
              ? 'Mi progreso'
              : 'Progreso de estudiantes',
          icon: Icons.trending_up,
          child: Column(
            children: practices.take(4).map((p) => _Progress(p)).toList(),
          ),
        ),
      ],
    );
  }

  void _showOverviewList(
    BuildContext context,
    String title,
    List<String> lines,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          shrinkWrap: true,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (lines.isEmpty)
              const Text('No hay datos disponibles por ahora.')
            else
              ...lines.map(
                (line) => ListTile(
                  leading: const Icon(Icons.chevron_right),
                  title: Text(line),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PracticesPage extends StatefulWidget {
  final AppUser user;
  final VoidCallback refresh;
  const _PracticesPage({required this.user, required this.refresh});
  @override
  State<_PracticesPage> createState() => _PracticesPageState();
}

class _PracticesPageState extends State<_PracticesPage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final all = LocalDataService.instance.getPracticesForUser(widget.user);
    final practices = _filter(
      all,
      q,
      (p) => '${p.student.name} ${p.company.name} ${p.status.label}',
    );
    final shell = context.findAncestorStateOfType<_AppShellState>();
    final canManage = widget.user.role == UserRole.supervisor;
    return _Page(
      title: 'Gestión de prácticas',
      search: _Search(
        onChanged: (v) => setState(() => q = v),
        hint: 'Buscar práctica, estudiante o empresa',
      ),
      children: practices
          .map(
            (p) => _PracticeTile(
              practice: p,
              onEdit: canManage ? () => shell?._openPracticeForm(p) : null,
              onDelete: canManage
                  ? () async {
                      if (shell?.remote.isReady ?? false) {
                        try {
                          await shell?.remote.deletePractice(p);
                        } catch (_) {
                          if (context.mounted) {
                            _toast(
                              context,
                              'No se pudo eliminar la práctica en Supabase.',
                            );
                          }
                        }
                      }
                      LocalDataService.instance.deletePractice(p.id);
                      widget.refresh();
                    }
                  : null,
            ),
          )
          .toList(),
    );
  }
}

class _StudentsPage extends StatefulWidget {
  final VoidCallback refresh;
  const _StudentsPage({required this.refresh});
  @override
  State<_StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<_StudentsPage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final shell = context.findAncestorStateOfType<_AppShellState>();
    final students = _filter(
      LocalDataService.instance.getStudents(),
      q,
      (s) => '${s.name} ${s.code} ${s.program} ${s.semester}',
    );
    return _Page(
      title: 'Estudiantes',
      search: _Search(
        onChanged: (v) => setState(() => q = v),
        hint: 'Buscar estudiante',
      ),
      children: students
          .map(
            (s) => _InfoTile(
              icon: Icons.school,
              title: s.name,
              subtitle:
                  '${s.code} - ${s.program}${s.semester.isEmpty ? '' : ' - Semestre ${s.semester}'}\n${s.phone}',
              trailing: Wrap(
                spacing: 2,
                runSpacing: 2,
                alignment: WrapAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => shell?._openStudentForm(s),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    onPressed: () async {
                      if (shell?.remote.isReady ?? false) {
                        try {
                          await shell?.remote.deleteStudent(s);
                        } catch (_) {
                          if (context.mounted) {
                            _toast(
                              context,
                              'No se pudo eliminar el estudiante en Supabase.',
                            );
                          }
                        }
                      }
                      LocalDataService.instance.deleteStudent(s.id);
                      widget.refresh();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CompaniesPage extends StatefulWidget {
  final VoidCallback refresh;
  const _CompaniesPage({required this.refresh});
  @override
  State<_CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<_CompaniesPage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final shell = context.findAncestorStateOfType<_AppShellState>();
    final companies = _filter(
      LocalDataService.instance.getCompanies(),
      q,
      (c) => '${c.name} ${c.ruc} ${c.email}',
    );
    return _Page(
      title: 'Empresas',
      search: _Search(
        onChanged: (v) => setState(() => q = v),
        hint: 'Buscar empresa',
      ),
      children: companies
          .map(
            (c) => _InfoTile(
              icon: Icons.apartment,
              title: c.name,
              subtitle:
                  '${c.address}\nVacantes disponibles: ${c.totalVacancies}\nGPS: ${c.latitude}, ${c.longitude}',
              trailing: Wrap(
                spacing: 2,
                runSpacing: 2,
                alignment: WrapAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => shell?._openCompanyForm(c),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    onPressed: () async {
                      if (shell?.remote.isReady ?? false) {
                        try {
                          await shell?.remote.deleteCompany(c);
                        } catch (_) {
                          if (context.mounted) {
                            _toast(
                              context,
                              'No se pudo eliminar la empresa en Supabase.',
                            );
                          }
                        }
                      }
                      LocalDataService.instance.deleteCompany(c.id);
                      widget.refresh();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CoordinatorsPage extends StatefulWidget {
  final VoidCallback refresh;
  const _CoordinatorsPage({required this.refresh});
  @override
  State<_CoordinatorsPage> createState() => _CoordinatorsPageState();
}

class _CoordinatorsPageState extends State<_CoordinatorsPage> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final data = LocalDataService.instance;
    final shell = context.findAncestorStateOfType<_AppShellState>();
    final coordinators = _filter(data.getUsersByRole(UserRole.encargado), q, (
      u,
    ) {
      final company = _companyById(u.companyId);
      return '${u.name} ${u.email} ${company?.name ?? ''}';
    });
    return _Page(
      title: 'Encargados',
      search: _Search(
        onChanged: (v) => setState(() => q = v),
        hint: 'Buscar encargado o empresa',
      ),
      children: [
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: MediaQuery.sizeOf(context).width < 380 ? 1.45 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _Mini('Encargados', '${coordinators.length}'),
            _Mini(
              'Asignados',
              '${coordinators.where((u) => u.companyId != null).length}',
            ),
          ],
        ),
        ...coordinators.map((u) {
          final company = _companyById(u.companyId);
          final practices = company == null
              ? <Practice>[]
              : data
                    .getPractices()
                    .where((p) => p.company.id == company.id)
                    .toList();
          return _InfoTile(
            icon: Icons.badge,
            title: u.name,
            subtitle:
                '${u.email}\nEmpresa: ${company?.name ?? 'Sin asignar'}\nPracticantes: ${practices.isEmpty ? 'Sin practicantes' : practices.map((p) => p.student.name).join(', ')}',
            trailing: IconButton(
              tooltip: 'Editar encargado',
              onPressed: () => shell?._openUserForm(u, UserRole.encargado),
              icon: const Icon(Icons.edit),
            ),
          );
        }),
      ],
    );
  }
}

class _VacanciesPage extends StatefulWidget {
  final AppUser user;
  const _VacanciesPage({required this.user});
  @override
  State<_VacanciesPage> createState() => _VacanciesPageState();
}

class _VacanciesPageState extends State<_VacanciesPage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final data = LocalDataService.instance;
    final shell = context.findAncestorStateOfType<_AppShellState>();
    final compact = MediaQuery.sizeOf(context).width < 380;
    final companies = _filter(
      data.getCompanies(),
      q,
      (c) => '${c.name} ${c.ruc} ${c.contact} ${c.totalVacancies}',
    );
    final totalVacancies = data.getCompanies().fold<int>(
      0,
      (sum, company) => sum + company.totalVacancies,
    );
    final companiesWithVacancies = data
        .getCompanies()
        .where((company) => company.totalVacancies > 0)
        .length;
    return _Page(
      title: 'Vacantes',
      search: _Search(
        onChanged: (v) => setState(() => q = v),
        hint: 'Buscar empresa o vacantes',
      ),
      children: [
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: compact ? 1.45 : 1.8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _Mini('Vacantes', '$totalVacancies'),
            _Mini('Empresas', '${data.getCompanies().length}'),
            _Mini('Con vacantes', '$companiesWithVacancies'),
            _Mini(
              'Sin vacantes',
              '${data.getCompanies().length - companiesWithVacancies}',
            ),
          ],
        ),
        ...companies.map(
          (company) => _InfoTile(
            icon: Icons.work,
            title: company.name,
            subtitle:
                '${company.ruc}\nVacantes disponibles: ${company.totalVacancies}\nContacto: ${company.contact}',
            trailing: IconButton(
              tooltip: 'Editar vacantes',
              onPressed: () => shell?._openCompanyForm(company),
              icon: const Icon(Icons.edit),
            ),
          ),
        ),
      ],
    );
  }
}

class _EvaluationPage extends StatefulWidget {
  final AppUser user;
  const _EvaluationPage({required this.user});
  @override
  State<_EvaluationPage> createState() => _EvaluationPageState();
}

class _EvaluationPageState extends State<_EvaluationPage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final data = LocalDataService.instance;
    final shell = context.findAncestorStateOfType<_AppShellState>();
    final practices = _filter(
      data.getPracticesForUser(widget.user),
      q,
      (p) => p.student.name,
    );
    return _Page(
      title: 'Evaluaciones',
      search: _Search(
        onChanged: (v) => setState(() => q = v),
        hint: 'Buscar estudiante evaluado',
      ),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _PdfButton(
            label: 'Exportar evaluaciones',
            lines: practices
                .expand(
                  (p) => data
                      .getEvaluations(p.id)
                      .map(
                        (e) =>
                            '${p.student.name} - ${e.title} - ${e.score}/100',
                      ),
                )
                .toList(),
          ),
        ),
        ...practices.map(
          (p) => ExpansionTile(
            title: Text(
              p.student.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(p.company.name),
            children: data
                .getEvaluations(p.id)
                .map(
                  (e) => ListTile(
                    title: Text(e.title),
                    subtitle: Text(
                      '${e.comment}\nDesempeño: ${e.performance.isEmpty ? 'No registrado' : e.performance}${e.pdfName == null ? '' : '\nPDF: ${e.pdfName}'}',
                    ),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${e.score}/100'),
                        if (widget.user.role == UserRole.supervisor)
                          IconButton(
                            tooltip: 'Editar evaluación',
                            onPressed: () => shell?._openEvaluationForm(e),
                            icon: const Icon(Icons.edit),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _AttendancePage extends StatefulWidget {
  final AppUser user;
  const _AttendancePage({required this.user});
  @override
  State<_AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<_AttendancePage> {
  String q = '';
  Practice? selected;
  @override
  Widget build(BuildContext context) {
    final data = LocalDataService.instance;
    final isStudent = widget.user.role == UserRole.estudiante;
    final compact = MediaQuery.sizeOf(context).width < 380;
    final practices = _filter(
      data.getPracticesForUser(widget.user),
      q,
      (p) => '${p.student.name} ${p.company.name}',
    );
    final current =
        selected ??
        (isStudent && practices.isNotEmpty ? practices.first : null);
    final attendance = current == null
        ? <Attendance>[]
        : data.getAttendances(current.id);
    final total = attendance.fold<double>(0, (s, a) => s + a.hours);
    final pct = current == null || current.requiredHours == 0
        ? 0
        : ((total / current.requiredHours) * 100).round();
    return _Page(
      title: 'Registro',
      search: _Search(
        onChanged: (v) => setState(() => q = v),
        hint: isStudent ? 'Buscar mi práctica' : 'Buscar estudiante',
      ),
      children: [
        if (!isStudent)
          _PracticeSelector(
            selected: selected,
            practices: practices,
            label: 'Seleccionar estudiante',
            onSelected: (p) => setState(() => selected = p),
          )
        else if (current != null)
          _InfoTile(
            icon: Icons.work_history,
            title: current.student.name,
            subtitle: '${current.company.name}\n${current.learningObjective}',
            trailing: _Pill(current.status.label, current.status.color),
          ),
        if (current != null) ...[
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: compact ? 1.75 : 2.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _Mini(
                'Presente',
                '${attendance.where((a) => a.status == AttendanceStatus.present).length}',
              ),
              _Mini(
                'Ausencia',
                '${attendance.where((a) => a.status == AttendanceStatus.absent).length}',
              ),
              _Mini(
                'Tardanza',
                '${attendance.where((a) => a.status == AttendanceStatus.late).length}',
              ),
              _Mini('Asistencia', '$pct%'),
            ],
          ),
          if (isStudent)
            _StudentAttendancePanel(
              practice: current,
              onAttendanceSaved: (attendance) async {
                final shell = context.findAncestorStateOfType<_AppShellState>();
                if (shell?.remote.isReady ?? false) {
                  try {
                    await shell?.remote.saveAttendance(attendance);
                    await shell?.remote.savePractice(current);
                  } catch (_) {
                    if (context.mounted) {
                      _toast(
                        context,
                        'No se pudo guardar la asistencia en Supabase.',
                      );
                    }
                  }
                }
              },
              onChanged: () => setState(() {}),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: _PdfButton(
              label: 'Exportar asistencia',
              enabled: attendance.isNotEmpty,
              lines: attendance
                  .map(
                    (a) =>
                        '${_date(a.date)} - ${a.status.label} - ${a.notes} - GPS ${a.latitude}, ${a.longitude}',
                  )
                  .toList(),
            ),
          ),
          ...attendance.map(
            (a) => _InfoTile(
              icon: Icons.location_on,
              title: '${_date(a.date)} - ${a.status.label}',
              subtitle:
                  '${a.notes}\n${a.hours}h - GPS: ${a.latitude.toStringAsFixed(5)}, ${a.longitude.toStringAsFixed(5)}',
              trailing: widget.user.role == UserRole.encargado
                  ? IconButton(
                      tooltip: 'Editar asistencia',
                      onPressed: () => _editAttendanceStatus(a),
                      icon: const Icon(Icons.edit),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _editAttendanceStatus(Attendance attendance) async {
    final selected = await showModalBottomSheet<AttendanceStatus>(
      context: context,
      useSafeArea: true,
      shape: _sheetShape,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Editar asistencia',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ...[
                AttendanceStatus.absent,
                AttendanceStatus.present,
                AttendanceStatus.late,
                AttendanceStatus.permission,
              ].map(
                (status) => ListTile(
                  leading: Icon(
                    status == attendance.status
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                  ),
                  title: Text(status.label),
                  onTap: () => Navigator.pop(context, status),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    setState(() {
      attendance.status = selected;
      attendance.notes = selected.label;
      if (selected == AttendanceStatus.absent) attendance.hours = 0;
    });
    final shell = context.findAncestorStateOfType<_AppShellState>();
    if (shell?.remote.isReady ?? false) {
      try {
        await shell?.remote.saveAttendance(attendance);
      } catch (_) {
        if (mounted) {
          _toast(context, 'No se pudo actualizar la asistencia en Supabase.');
        }
      }
    }
  }
}

class _StudentAttendancePanel extends StatelessWidget {
  final Practice practice;
  final Future<void> Function(Attendance attendance) onAttendanceSaved;
  final VoidCallback onChanged;
  const _StudentAttendancePanel({
    required this.practice,
    required this.onAttendanceSaved,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final data = LocalDataService.instance;
    final session = data.getOpenAttendanceSession(practice.id);
    final hasGps = session?.gpsVerified ?? false;
    final hasEntry = session?.checkInTime != null;
    final title = hasGps ? 'Ubicación verificada' : _date(DateTime.now());
    final buttonText = !hasGps
        ? 'Verificar GPS y registrar asistencia'
        : hasEntry
        ? 'Registrar salida'
        : 'Confirmar entrada';
    final buttonColor = hasEntry
        ? const Color(0xFFF97316)
        : const Color(0xFF2563EB);

    return _Card(
      title: title,
      icon: hasGps ? Icons.location_on : Icons.today,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasEntry)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${_time(session!.checkInTime!)} - GPS Verificado',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Primero valida tu ubicación antes de marcar.'),
            ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: buttonColor),
            onPressed: () async {
              if (!hasGps) {
                final position = await _currentDevicePosition();
                if (position == null) {
                  if (context.mounted) {
                    _toast(
                      context,
                      'Activa la ubicación y concede permiso para registrar asistencia.',
                    );
                  }
                  return;
                }
                data.verifyAttendanceGps(
                  practice.id,
                  latitude: position.latitude,
                  longitude: position.longitude,
                );
                _toast(context, 'GPS verificado correctamente');
              } else if (!hasEntry) {
                data.confirmAttendanceEntry(practice.id);
                _toast(context, 'Entrada confirmada');
              } else {
                final attendance = data.completeAttendanceExit(practice.id);
                await onAttendanceSaved(attendance);
                _toast(context, 'Salida registrada');
              }
              onChanged();
            },
            icon: Icon(hasEntry ? Icons.logout : Icons.my_location),
            label: Text(buttonText),
          ),
        ],
      ),
    );
  }
}

class _TrackingPage extends StatefulWidget {
  final AppUser user;
  const _TrackingPage({required this.user});
  @override
  State<_TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<_TrackingPage> {
  String q = '';
  Practice? selected;
  @override
  Widget build(BuildContext context) {
    final shell = context.findAncestorStateOfType<_AppShellState>();
    final practices = _filter(
      LocalDataService.instance.getPracticesForUser(widget.user),
      q,
      (p) => p.student.name,
    );
    return _Page(
      title: 'Seguimiento',
      search: _Search(
        onChanged: (v) => setState(() => q = v),
        hint: 'Buscar estudiante',
      ),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.user.role == UserRole.supervisor)
                FilledButton.icon(
                  onPressed: () => shell?._openTrackingForm(),
                  icon: const Icon(Icons.add_chart),
                  label: const Text('Nuevo seguimiento'),
                )
              else
                const SizedBox.shrink(),
              _PdfButton(
                label: 'Progreso general',
                lines: practices
                    .map(
                      (p) =>
                          '${p.student.name} - ${(p.progress * 100).round()}%',
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        _PracticeSelector(
          selected: selected,
          practices: practices,
          label: 'Seleccionar estudiante',
          onSelected: (p) => setState(() => selected = p),
        ),
        if (selected != null)
          _TrackingDetail(practice: selected!, user: widget.user),
      ],
    );
  }
}

class _TrackingDetail extends StatelessWidget {
  final Practice practice;
  final AppUser user;
  const _TrackingDetail({required this.practice, required this.user});
  @override
  Widget build(BuildContext context) {
    final data = LocalDataService.instance;
    final shell = context.findAncestorStateOfType<_AppShellState>();
    final records = data.getTrackingRecords(practice.id);
    return _Card(
      title: practice.student.name,
      icon: Icons.timeline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Progress(practice),
          _PdfButton(
            label: 'Seguimiento ${practice.student.code}',
            lines: [
              '${practice.student.name} - ${(practice.progress * 100).round()}%',
              ...records.map(
                (record) =>
                    '${record.title} - ${record.progress}%\nCumple: ${record.completedObjectives}\nPendiente: ${record.pendingObjectives}\n${record.monthlyReport}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...records.map(
            (record) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insights, color: Color(0xFF4F46E5)),
              title: Text(
                '${record.title} - ${record.progress}%',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Objetivos cumplidos: ${record.completedObjectives.isEmpty ? 'Sin registrar' : record.completedObjectives}\n'
                'Objetivos pendientes: ${record.pendingObjectives.isEmpty ? 'Sin registrar' : record.pendingObjectives}\n'
                'Informe mensual: ${record.monthlyReport.isEmpty ? 'Sin registrar' : record.monthlyReport}'
                '${record.pdfName == null ? '' : '\nPDF: ${record.pdfName}'}',
              ),
              trailing: user.role == UserRole.supervisor
                  ? IconButton(
                      tooltip: 'Editar seguimiento',
                      onPressed: () => shell?._openTrackingForm(record),
                      icon: const Icon(Icons.edit),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosurePage extends StatefulWidget {
  final VoidCallback refresh;
  const _ClosurePage({required this.refresh});

  @override
  State<_ClosurePage> createState() => _ClosurePageState();
}

class _ClosurePageState extends State<_ClosurePage> {
  String q = '';
  Practice? selected;

  @override
  Widget build(BuildContext context) {
    final data = LocalDataService.instance;
    final all = data.getPractices();
    final completed = all
        .where((p) => p.status == PracticeStatus.completed)
        .length;
    final issued = all.where((p) => p.certificateIssued).length;
    final ready = all
        .where((p) => _ClosureValidation.from(p).ready && !p.certificateIssued)
        .length;
    final practices = _filter(
      all,
      q,
      (p) => '${p.student.name} ${p.student.code} ${p.company.name}',
    );
    final compact = MediaQuery.sizeOf(context).width < 380;

    return _Page(
      title: 'Cierre de prácticas',
      search: _Search(
        onChanged: (v) => setState(() => q = v),
        hint: 'Buscar estudiante con práctica a cerrar',
      ),
      children: [
        GridView.count(
          crossAxisCount: 3,
          childAspectRatio: compact ? .88 : 1.1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _Mini('Completadas', '$completed'),
            _Mini('Listas para cerrar', '$ready'),
            _Mini('Certificados emitidos', '$issued'),
          ],
        ),
        _PracticeSelector(
          selected: selected,
          practices: practices,
          label: 'Seleccionar estudiante',
          onSelected: (p) => setState(() => selected = p),
        ),
        if (selected != null)
          _ClosureDetail(
            practice: selected!,
            onClosed: () async {
              final validation = _ClosureValidation.from(selected!);
              if (!validation.ready) {
                _toast(context, 'Hay requisitos pendientes.');
                return;
              }
              LocalDataService.instance.closePractice(selected!.id);
              final file = await _createCertificate(selected!);
              final shell = context.findAncestorStateOfType<_AppShellState>();
              if (shell?.remote.isReady ?? false) {
                try {
                  final bytes = await file.readAsBytes();
                  final storagePath =
                      'certificados/${DateTime.now().millisecondsSinceEpoch}-${selected!.student.code}.pdf';
                  final uploaded = await shell!.remote.uploadDocument(
                    path: storagePath,
                    bytes: bytes,
                  );
                  await shell.remote.saveCertificate(
                    selected!,
                    pdfPath: uploaded,
                  );
                } catch (_) {
                  if (context.mounted) {
                    _toast(
                      context,
                      'No se pudo registrar el certificado en Supabase.',
                    );
                  }
                }
              }
              if (!mounted) return;
              widget.refresh();
              setState(() {});
              await PdfReportService.saveOrShareFile(
                file,
                'Certificado ${selected!.student.name}',
              );
              if (context.mounted) {
                _toast(context, 'Certificado guardado o listo para compartir.');
              }
            },
          ),
      ],
    );
  }

  Future<dynamic> _createCertificate(Practice practice) {
    return PdfReportService.createSimpleReport(
      fileName:
          'certificado_${practice.student.name}_${DateTime.now().toIso8601String().split('T').first}',
      title: 'CERTIFICADO DE PRÁCTICA CONCLUIDA',
      lines: [
        'IESTP Contralmirante Manuel Villar Olivera',
        '',
        'Se deja constancia que:',
        practice.student.name,
        'Código: ${practice.student.code}',
        'Programa de estudios: ${practice.student.program}',
        '',
        'Ha culminado satisfactoriamente sus prácticas profesionales en:',
        practice.company.name,
        'Periodo: ${_date(practice.startDate)} al ${_date(practice.endDate)}',
        'Total de horas: ${practice.requiredHours}',
        '',
        'Resultado: PRÁCTICA CONCLUIDA Y APROBADA',
        'Fecha de emisión: ${_date(DateTime.now())}',
      ],
    );
  }
}

class _ClosureDetail extends StatelessWidget {
  final Practice practice;
  final VoidCallback onClosed;
  const _ClosureDetail({required this.practice, required this.onClosed});

  @override
  Widget build(BuildContext context) {
    final validation = _ClosureValidation.from(practice);
    return Column(
      children: [
        _Card(
          title: 'Validacion de requisitos',
          icon: Icons.verified_user,
          child: Column(
            children: [
              _ReqRow(
                'Horas completadas',
                validation.hoursOk,
                '${practice.accumulatedHours}/${practice.requiredHours}h',
              ),
              _ReqRow(
                'Evaluaciones parciales',
                validation.partialOk,
                '${validation.partialCount} registradas',
              ),
              _ReqRow(
                'Evaluación final',
                validation.finalOk,
                validation.finalOk ? 'Registrada' : 'Pendiente',
              ),
              _ReqRow(
                'Nota minima aprobatoria',
                validation.gradeOk,
                '${validation.averageScore}/100',
              ),
              _ReqRow(
                'Asistencias minimas',
                validation.attendanceOk,
                '${validation.attendancePercent}%',
              ),
              _ReqRow(
                'Objetivos cumplidos',
                validation.objectivesOk,
                validation.objectivesOk
                    ? 'Completos'
                    : '${practice.pendingObjectives.length} pendientes',
              ),
            ],
          ),
        ),
        _Card(
          title: 'Informacion del estudiante',
          icon: Icons.school,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoLine('Nombre completo', practice.student.name),
              _InfoLine('Código', practice.student.code),
              _InfoLine('Programa', practice.student.program),
              _InfoLine('Empresa', practice.company.name),
              _InfoLine(
                'Periodo',
                '${_date(practice.startDate)} - ${_date(practice.endDate)}',
              ),
              _InfoLine('Total de horas', '${practice.requiredHours}'),
            ],
          ),
        ),
        _Card(
          title: validation.ready
              ? 'Práctica lista para cerrar'
              : 'Requisitos pendientes',
          icon: validation.ready ? Icons.task_alt : Icons.warning_amber,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                validation.ready
                    ? 'El estudiante cumplio todos los requisitos para culminar el proceso.'
                    : 'Complete los requisitos antes de cerrar la práctica.',
              ),
              if (!validation.ready) ...[
                const SizedBox(height: 8),
                ...validation.pending.map((item) => Text('- $item')),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: validation.ready ? onClosed : null,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(
                    practice.certificateIssued
                        ? 'Reemitir certificado'
                        : 'Cerrar práctica',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClosureValidation {
  final bool hoursOk;
  final bool partialOk;
  final bool finalOk;
  final bool gradeOk;
  final bool attendanceOk;
  final bool objectivesOk;
  final int partialCount;
  final int averageScore;
  final int attendancePercent;

  const _ClosureValidation({
    required this.hoursOk,
    required this.partialOk,
    required this.finalOk,
    required this.gradeOk,
    required this.attendanceOk,
    required this.objectivesOk,
    required this.partialCount,
    required this.averageScore,
    required this.attendancePercent,
  });

  bool get ready =>
      hoursOk &&
      partialOk &&
      finalOk &&
      gradeOk &&
      attendanceOk &&
      objectivesOk;

  List<String> get pending => [
    if (!hoursOk) 'Horas completadas',
    if (!partialOk) 'Evaluaciones parciales',
    if (!finalOk) 'Evaluación final',
    if (!gradeOk) 'Nota minima aprobatoria',
    if (!attendanceOk) 'Asistencias minimas',
    if (!objectivesOk) 'Objetivos cumplidos',
  ];

  static _ClosureValidation from(Practice practice) {
    final data = LocalDataService.instance;
    final evaluations = data.getEvaluations(practice.id);
    final partialCount = evaluations
        .where((e) => e.title.toLowerCase().contains('parcial'))
        .length;
    final finalOk = evaluations.any(
      (e) => e.title.toLowerCase().contains('final'),
    );
    final average = evaluations.isEmpty
        ? 0
        : (evaluations.fold<int>(0, (sum, e) => sum + e.score) /
                  evaluations.length)
              .round();
    final attendanceHours = data
        .getAttendances(practice.id)
        .fold<double>(0, (sum, a) => sum + a.hours);
    final attendancePercent = practice.requiredHours == 0
        ? 0
        : (((attendanceHours / practice.requiredHours) * 100)
                  .clamp(0, 100)
                  .round())
              .clamp((practice.progress * 100).round(), 100);
    return _ClosureValidation(
      hoursOk: practice.accumulatedHours >= practice.requiredHours,
      partialOk: partialCount >= 1,
      finalOk: finalOk,
      gradeOk: average >= 70,
      attendanceOk: attendancePercent >= 70,
      objectivesOk: practice.pendingObjectives.isEmpty,
      partialCount: partialCount,
      averageScore: average,
      attendancePercent: attendancePercent,
    );
  }
}

class _ReqRow extends StatelessWidget {
  final String label;
  final bool ok;
  final String value;
  const _ReqRow(this.label, this.ok, this.value);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ok ? Icons.check_circle : Icons.cancel,
        color: ok ? Colors.green : Colors.red,
      ),
      title: Text(label),
      trailing: Text(value),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsPage extends StatelessWidget {
  final AppUser user;
  const _ReportsPage({required this.user});
  @override
  Widget build(BuildContext context) {
    final data = LocalDataService.instance;
    if (user.role == UserRole.encargado) {
      final practices = data.getPracticesForUser(user);
      return _Page(
        title: 'Reportes',
        children: [
          _PdfButton(
            label: 'Registro de asistencia',
            lines: practices
                .expand(
                  (p) => data
                      .getAttendances(p.id)
                      .map(
                        (a) =>
                            '${p.student.name} - ${_date(a.date)} - ${a.status.label} - ${a.hours}h',
                      ),
                )
                .toList(),
          ),
          _PdfButton(
            label: 'Seguimiento',
            lines: practices
                .map(
                  (p) =>
                      '${p.student.name} - ${p.company.name} - ${(p.progress * 100).round()}%',
                )
                .toList(),
          ),
          _PdfButton(
            label: 'Prácticas',
            lines: practices
                .map(
                  (p) =>
                      '${p.student.name} - ${p.company.name} - ${p.status.label} - Módulo: ${p.practiceModule} - Turno: ${p.shift}',
                )
                .toList(),
          ),
        ],
      );
    }
    return _Page(
      title: 'Reportes',
      children: [
        _PdfButton(
          label: 'Reporte general supervisor',
          lines: [
            'RESUMEN GENERAL PRÁCTICAPP',
            'Usuarios: ${data.getUsers().length}',
            'Estudiantes: ${data.getStudents().length}',
            'Empresas: ${data.getCompanies().length}',
            'Prácticas: ${data.getPractices().length}',
            'Vacantes: ${data.getCompanies().fold<int>(0, (sum, c) => sum + c.totalVacancies)}',
            'Evaluaciones: ${data.getPractices().fold<int>(0, (sum, p) => sum + data.getEvaluations(p.id).length)}',
            '',
            'PRÁCTICAS',
            ...data.getPractices().map(
              (p) =>
                  '${p.id} - ${p.student.name} - ${p.company.name} - ${p.status.label} - ${(p.progress * 100).round()}%',
            ),
            '',
            'ESTUDIANTES',
            ...data.getStudents().map(
              (s) => '${s.code} - ${s.name} - ${s.program}',
            ),
            '',
            'EMPRESAS',
            ...data.getCompanies().map(
              (c) =>
                  '${c.ruc} - ${c.name} - Vacantes: ${c.totalVacancies} - GPS ${c.latitude}, ${c.longitude}',
            ),
            '',
            'VACANTES',
            ...data.getCompanies().map(
              (c) => '${c.name} - Vacantes disponibles: ${c.totalVacancies}',
            ),
            '',
            'REGISTRO DE ASISTENCIA',
            ...data.getPractices().expand(
              (p) => data
                  .getAttendances(p.id)
                  .take(3)
                  .map(
                    (a) =>
                        '${p.student.name} - ${_date(a.date)} - ${a.status.label} - ${a.hours}h',
                  ),
            ),
            '',
            'EVALUACIONES',
            ...data.getPractices().expand(
              (p) => data
                  .getEvaluations(p.id)
                  .map(
                    (e) => '${p.student.name} - ${e.title} - ${e.score}/100',
                  ),
            ),
            '',
            'CIERRE DE PRÁCTICAS',
            ...data.getPractices().map((p) {
              final validation = _ClosureValidation.from(p);
              return '${p.student.name} - ${validation.ready ? 'Lista para cerrar' : 'Requisitos pendientes'} - Certificado: ${p.certificateIssued ? 'Emitido' : 'Pendiente'}';
            }),
            '',
            'USUARIOS',
            ...data.getUsers().map(
              (u) => '${u.name} - ${u.role.label} - ${u.email}',
            ),
          ],
        ),
        _PdfButton(
          label: 'Certificados emitidos',
          lines: data
              .getPractices()
              .where((p) => p.status == PracticeStatus.completed)
              .map(
                (p) =>
                    '${p.student.name} - ${p.student.code} - ${p.company.name} - ${p.certificateIssued ? 'Emitido' : 'Pendiente de emisión'}',
              )
              .toList(),
        ),
        _PdfButton(
          label: 'Prácticas',
          lines: data
              .getPractices()
              .map((p) => '${p.student.name} - ${p.company.name}')
              .toList(),
        ),
        _PdfButton(
          label: 'Estudiantes',
          lines: data
              .getStudents()
              .map((s) => '${s.code} - ${s.name}')
              .toList(),
        ),
        _PdfButton(
          label: 'Empresas',
          lines: data
              .getCompanies()
              .map((c) => '${c.ruc} - ${c.name}')
              .toList(),
        ),
        _PdfButton(
          label: 'Usuarios',
          lines: data
              .getUsers()
              .map((u) => '${u.name} - ${u.role.label}')
              .toList(),
        ),
      ],
    );
  }
}

class _UsersPage extends StatefulWidget {
  final VoidCallback refresh;
  const _UsersPage({required this.refresh});
  @override
  State<_UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<_UsersPage> {
  UserRole? role;
  final visible = <String, bool>{};
  @override
  Widget build(BuildContext context) {
    final shell = context.findAncestorStateOfType<_AppShellState>();
    final compact = MediaQuery.sizeOf(context).width < 380;
    final all = LocalDataService.instance
        .getUsers()
        .where((user) => user.role != UserRole.empresa)
        .toList();
    final users = role == null
        ? all
        : all.where((u) => u.role == role).toList();
    return _Page(
      title: 'Usuarios',
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: role == null,
              onSelected: (_) => setState(() => role = null),
            ),
            ...UserRole.values
                .where((r) => r != UserRole.empresa)
                .map(
                  (r) => ChoiceChip(
                    label: Text(r.label),
                    selected: role == r,
                    onSelected: (_) => setState(() => role = r),
                  ),
                ),
          ],
        ),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: compact ? 1.55 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: UserRole.values
              .where((r) => r != UserRole.empresa)
              .map(
                (r) =>
                    _Mini(r.label, '${all.where((u) => u.role == r).length}'),
              )
              .toList(),
        ),
        ...users.map((u) {
          final show = visible[u.id] ?? false;
          final company = _companyById(u.companyId);
          final student = _studentById(u.studentId);
          final linked = u.role == UserRole.encargado
              ? '\nEmpresa: ${company?.name ?? 'Sin asignar'}'
              : u.role == UserRole.estudiante
              ? '\nEstudiante: ${student?.name ?? 'Sin vincular'}'
              : '';
          return _InfoTile(
            icon: u.role.icon,
            title: u.name,
            subtitle:
                '${u.email}$linked\nClave: ${show ? u.password : '********'}',
            trailing: Wrap(
              spacing: 2,
              runSpacing: 2,
              alignment: WrapAlignment.end,
              children: [
                IconButton(
                  onPressed: () => setState(() => visible[u.id] = !show),
                  icon: Icon(show ? Icons.visibility_off : Icons.visibility),
                ),
                IconButton(
                  onPressed: () => shell?._openUserForm(u),
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  onPressed: () async {
                    if (shell?.remote.isReady ?? false) {
                      try {
                        await shell?.remote.adminDeleteUser(u);
                      } catch (_) {
                        if (context.mounted) {
                          _toast(
                            context,
                            'No se pudo eliminar el usuario en Supabase.',
                          );
                        }
                      }
                    }
                    LocalDataService.instance.deleteUser(u.id);
                    widget.refresh();
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _PracticeFormData {
  final Student student;
  final Company company;
  final String practiceModule;
  final String shift;
  final DateTime startDate;
  final int requiredHours;
  final String learningObjective;
  _PracticeFormData(
    this.student,
    this.company,
    this.practiceModule,
    this.shift,
    this.startDate,
    this.requiredHours,
    this.learningObjective,
  );
}

class _PracticeForm extends StatefulWidget {
  final Practice? initial;
  const _PracticeForm({this.initial});
  @override
  State<_PracticeForm> createState() => _PracticeFormState();
}

class _PracticeFormState extends State<_PracticeForm> {
  static const shifts = ['Mañana', 'Tarde', 'Día completo'];
  late Student student = widget.initial?.student ?? _firstStudent();
  late Company company = widget.initial?.company ?? _firstCompany();
  late String practiceModule =
      LocalDataService.practiceModules.contains(widget.initial?.practiceModule)
      ? widget.initial!.practiceModule
      : LocalDataService.practiceModules.first;
  late String shift = shifts.contains(widget.initial?.shift)
      ? widget.initial!.shift
      : 'Día completo';
  late DateTime start = widget.initial?.startDate ?? DateTime.now();
  late final hours = TextEditingController(
    text: '${widget.initial?.requiredHours ?? 480}',
  );
  late final objective = TextEditingController(
    text: widget.initial?.learningObjective ?? '',
  );

  Student _firstStudent() {
    final students = LocalDataService.instance.getStudents().toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return students.first;
  }

  Company _firstCompany() {
    final companies = LocalDataService.instance.getCompanies().toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return companies.first;
  }

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: widget.initial == null ? 'Nueva práctica' : 'Editar práctica',
      children: [
        _PickerField<Student>(
          label: 'Estudiante',
          value: student,
          items: LocalDataService.instance.getStudents().toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
          labelOf: (s) => '${s.name} - ${s.code}',
          onChanged: (v) => setState(() => student = v),
        ),
        _PickerField<Company>(
          label: 'Empresa',
          value: company,
          items: LocalDataService.instance.getCompanies().toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
          labelOf: (c) => c.name,
          onChanged: (v) => setState(() => company = v),
        ),
        DropdownButtonFormField<String>(
          value: practiceModule,
          items: LocalDataService.practiceModules
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (m) =>
              setState(() => practiceModule = m ?? practiceModule),
          decoration: const InputDecoration(labelText: 'Módulo de práctica'),
        ),
        DropdownButtonFormField<String>(
          value: shift,
          items: shifts
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (s) => setState(() => shift = s ?? shift),
          decoration: const InputDecoration(labelText: 'Turno'),
        ),
        Row(
          children: [
            Expanded(
              child: _DateButton(
                label: 'Inicio',
                date: start,
                onPick: (d) => setState(() => start = d),
              ),
            ),
          ],
        ),
        TextField(
          controller: hours,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Horas requeridas'),
        ),
        TextField(
          controller: objective,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Objetivo de aprendizaje',
          ),
        ),
      ],
      saveLabel: 'Guardar práctica',
      onSave: () {
        final parsedHours = int.tryParse(hours.text.trim());
        if (parsedHours == null || parsedHours <= 0) {
          _toast(context, 'Ingresa las horas requeridas.');
          return;
        }
        if (objective.text.trim().isEmpty) {
          _toast(context, 'Ingresa el objetivo de aprendizaje.');
          return;
        }
        Navigator.pop(
          context,
          _PracticeFormData(
            student,
            company,
            practiceModule,
            shift,
            start,
            parsedHours,
            objective.text.trim(),
          ),
        );
      },
    );
  }
}

class _StudentForm extends StatefulWidget {
  final Student? initial;
  const _StudentForm({this.initial});
  @override
  State<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<_StudentForm> {
  late final name = TextEditingController(text: widget.initial?.name ?? '');
  late final code = TextEditingController(text: widget.initial?.code ?? '');
  late final phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final semester = TextEditingController(
    text: widget.initial?.semester ?? '',
  );
  late String program =
      widget.initial?.program ?? LocalDataService.programs.first;
  @override
  Widget build(BuildContext context) => _FormScaffold(
    title: widget.initial == null ? 'Agregar estudiante' : 'Editar estudiante',
    children: [
      TextField(
        controller: name,
        decoration: const InputDecoration(labelText: 'Nombre completo'),
      ),
      TextField(
        controller: code,
        decoration: const InputDecoration(labelText: 'Código de estudiante'),
      ),
      TextField(
        controller: phone,
        decoration: const InputDecoration(labelText: 'Teléfono'),
      ),
      TextField(
        controller: semester,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Semestre',
          hintText: 'Ejemplo: I, II, III, IV, V o VI',
        ),
      ),
      DropdownButtonFormField<String>(
        value: program,
        items: LocalDataService.programs
            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
            .toList(),
        onChanged: (v) => setState(() => program = v ?? program),
        decoration: const InputDecoration(labelText: 'Programa de estudios'),
      ),
    ],
    saveLabel: 'Agregar',
    onSave: () {
      if (name.text.trim().isEmpty) {
        _toast(context, 'Ingresa el nombre del estudiante.');
        return;
      }
      if (code.text.trim().isEmpty) {
        _toast(context, 'Ingresa el código del estudiante.');
        return;
      }
      if (phone.text.trim().isEmpty) {
        _toast(context, 'Ingresa el teléfono del estudiante.');
        return;
      }
      if (semester.text.trim().isEmpty) {
        _toast(context, 'Ingresa el semestre del estudiante.');
        return;
      }
      Navigator.pop(
        context,
        Student(
          id: widget.initial?.id ?? '',
          name: name.text.trim(),
          code: code.text.trim(),
          email: widget.initial?.email ?? '',
          phone: phone.text.trim(),
          program: program,
          semester: semester.text.trim(),
        ),
      );
    },
  );
}

class _CompanyForm extends StatefulWidget {
  final Company? initial;
  const _CompanyForm({this.initial});
  @override
  State<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends State<_CompanyForm> {
  late final name = TextEditingController(text: widget.initial?.name ?? '');
  late final ruc = TextEditingController(text: widget.initial?.ruc ?? '');
  late final phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final address = TextEditingController(
    text: widget.initial?.address ?? '',
  );
  late final contact = TextEditingController(
    text: widget.initial?.contact ?? '',
  );
  late final email = TextEditingController(text: widget.initial?.email ?? '');
  late final lat = TextEditingController(
    text: '${widget.initial?.latitude ?? -3.6817}',
  );
  late final lng = TextEditingController(
    text: '${widget.initial?.longitude ?? -80.6760}',
  );
  late final totalVacancies = TextEditingController(
    text: '${widget.initial?.totalVacancies ?? 0}',
  );
  @override
  Widget build(BuildContext context) => _FormScaffold(
    title: widget.initial == null ? 'Registrar empresa' : 'Editar empresa',
    children: [
      TextField(
        controller: name,
        decoration: const InputDecoration(labelText: 'Nombre de la empresa *'),
      ),
      TextField(
        controller: ruc,
        decoration: const InputDecoration(labelText: 'RUC *'),
      ),
      TextField(
        controller: phone,
        decoration: const InputDecoration(labelText: 'Teléfono'),
      ),
      TextField(
        controller: address,
        decoration: const InputDecoration(labelText: 'Dirección'),
      ),
      TextField(
        controller: contact,
        decoration: const InputDecoration(labelText: 'Persona contacto'),
      ),
      TextField(
        controller: email,
        decoration: const InputDecoration(labelText: 'Email *'),
      ),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: lat,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Latitud GPS *'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: lng,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Longitud GPS *'),
            ),
          ),
        ],
      ),
      TextField(
        controller: totalVacancies,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Total de vacantes disponibles *',
        ),
      ),
    ],
    saveLabel: 'Registrar empresa',
    onSave: () {
      final latitude = double.tryParse(lat.text.trim());
      final longitude = double.tryParse(lng.text.trim());
      final vacancies = int.tryParse(totalVacancies.text.trim());
      if (name.text.trim().isEmpty) {
        _toast(context, 'Ingresa el nombre de la empresa.');
        return;
      }
      if (ruc.text.trim().isEmpty) {
        _toast(context, 'Ingresa el RUC de la empresa.');
        return;
      }
      if (email.text.trim().isEmpty || !email.text.contains('@')) {
        _toast(context, 'Ingresa un email válido.');
        return;
      }
      if (latitude == null || longitude == null) {
        _toast(context, 'Ingresa coordenadas GPS válidas.');
        return;
      }
      if (vacancies == null || vacancies < 0) {
        _toast(context, 'Ingresa el total de vacantes disponibles.');
        return;
      }
      Navigator.pop(
        context,
        Company(
          id: widget.initial?.id ?? '',
          name: name.text.trim(),
          ruc: ruc.text.trim(),
          address: address.text.trim(),
          contact: contact.text.trim(),
          phone: phone.text.trim(),
          email: email.text.trim(),
          latitude: latitude,
          longitude: longitude,
          totalVacancies: vacancies.clamp(0, 999).toInt(),
        ),
      );
    },
  );
}

class _EvaluationFormData {
  final Practice practice;
  final String title;
  final int score;
  final String comment;
  final String performance;
  final String? pdfName;
  _EvaluationFormData(
    this.practice,
    this.title,
    this.score,
    this.comment,
    this.performance,
    this.pdfName,
  );
}

class _EvaluationForm extends StatefulWidget {
  final Evaluation? initial;
  const _EvaluationForm({this.initial});
  @override
  State<_EvaluationForm> createState() => _EvaluationFormState();
}

class _EvaluationFormState extends State<_EvaluationForm> {
  late Practice practice =
      LocalDataService.instance.getPracticeById(
        widget.initial?.practiceId ?? '',
      ) ??
      LocalDataService.instance.getPractices().first;
  late final title = TextEditingController(text: widget.initial?.title ?? '');
  late final score = TextEditingController(
    text: '${widget.initial?.score ?? 80}',
  );
  late final comment = TextEditingController(
    text: widget.initial?.comment ?? '',
  );
  late final performance = TextEditingController(
    text: widget.initial?.performance ?? '',
  );
  late String? pdfName = widget.initial?.pdfName;
  @override
  Widget build(BuildContext context) => _FormScaffold(
    title: widget.initial == null ? 'Nueva evaluación' : 'Editar evaluación',
    children: [
      _PickerField<Practice>(
        label: 'Estudiante',
        value: practice,
        items: LocalDataService.instance.getPractices(),
        labelOf: (p) => p.student.name,
        onChanged: (p) => setState(() => practice = p),
      ),
      TextField(
        controller: title,
        decoration: const InputDecoration(labelText: 'Título'),
      ),
      TextField(
        controller: score,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Puntaje 0-100'),
      ),
      TextField(
        controller: comment,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(labelText: 'Comentario'),
      ),
      TextField(
        controller: performance,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(labelText: 'Desempeño'),
      ),
      _OptionalPdfField(
        pdfName: pdfName,
        prefix: 'evaluacion',
        onChanged: (value) => setState(() => pdfName = value),
      ),
    ],
    saveLabel: 'Guardar evaluación',
    onSave: () {
      final parsedScore = int.tryParse(score.text.trim());
      if (title.text.trim().isEmpty) {
        _toast(context, 'Ingresa el título de la evaluación.');
        return;
      }
      if (parsedScore == null || parsedScore < 0 || parsedScore > 100) {
        _toast(context, 'Ingresa un puntaje válido entre 0 y 100.');
        return;
      }
      if (comment.text.trim().isEmpty) {
        _toast(context, 'Ingresa el comentario de la evaluación.');
        return;
      }
      if (performance.text.trim().isEmpty) {
        _toast(context, 'Ingresa el desempeño de la evaluación.');
        return;
      }
      Navigator.pop(
        context,
        _EvaluationFormData(
          practice,
          title.text.trim(),
          parsedScore,
          comment.text.trim(),
          performance.text.trim(),
          pdfName,
        ),
      );
    },
  );
}

class _TrackingForm extends StatefulWidget {
  final TrackingRecord? initial;
  const _TrackingForm({this.initial});
  @override
  State<_TrackingForm> createState() => _TrackingFormState();
}

class _TrackingFormState extends State<_TrackingForm> {
  late Practice practice =
      LocalDataService.instance.getPracticeById(
        widget.initial?.practiceId ?? '',
      ) ??
      LocalDataService.instance.getPractices().first;
  late final title = TextEditingController(
    text: widget.initial?.title ?? 'Seguimiento mensual',
  );
  late final progress = TextEditingController(
    text: '${widget.initial?.progress ?? (practice.progress * 100).round()}',
  );
  late final completedObjectives = TextEditingController(
    text: widget.initial?.completedObjectives ?? '',
  );
  late final pendingObjectives = TextEditingController(
    text: widget.initial?.pendingObjectives ?? '',
  );
  late final monthlyReport = TextEditingController(
    text: widget.initial?.monthlyReport ?? '',
  );
  late String? pdfName = widget.initial?.pdfName;

  @override
  Widget build(BuildContext context) => _FormScaffold(
    title: widget.initial == null ? 'Nuevo seguimiento' : 'Editar seguimiento',
    children: [
      _PickerField<Practice>(
        label: 'Estudiante',
        value: practice,
        items: LocalDataService.instance.getPractices(),
        labelOf: (p) => '${p.student.name} - ${p.company.name}',
        onChanged: (p) => setState(() {
          practice = p;
          progress.text = '${(p.progress * 100).round()}';
        }),
      ),
      TextField(
        controller: title,
        decoration: const InputDecoration(labelText: 'Título del seguimiento'),
      ),
      TextField(
        controller: progress,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Progreso 0-100'),
      ),
      TextField(
        controller: completedObjectives,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(labelText: 'Objetivos cumplidos'),
      ),
      TextField(
        controller: pendingObjectives,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(labelText: 'Objetivos incumplidos'),
      ),
      TextField(
        controller: monthlyReport,
        minLines: 3,
        maxLines: 7,
        decoration: const InputDecoration(labelText: 'Informe mensual'),
      ),
      _OptionalPdfField(
        pdfName: pdfName,
        prefix: 'seguimiento',
        onChanged: (value) => setState(() => pdfName = value),
      ),
    ],
    saveLabel: 'Guardar seguimiento',
    onSave: () {
      final parsedProgress = int.tryParse(progress.text.trim());
      if (title.text.trim().isEmpty) {
        _toast(context, 'Ingresa el título del seguimiento.');
        return;
      }
      if (parsedProgress == null ||
          parsedProgress < 0 ||
          parsedProgress > 100) {
        _toast(context, 'Ingresa un progreso válido entre 0 y 100.');
        return;
      }
      if (monthlyReport.text.trim().isEmpty) {
        _toast(context, 'Ingresa el informe mensual.');
        return;
      }
      Navigator.pop(
        context,
        TrackingRecord(
          id: widget.initial?.id ?? '',
          practiceId: practice.id,
          title: title.text.trim(),
          progress: parsedProgress,
          completedObjectives: completedObjectives.text.trim(),
          pendingObjectives: pendingObjectives.text.trim(),
          monthlyReport: monthlyReport.text.trim(),
          pdfName: pdfName,
        ),
      );
    },
  );
}

class _OptionalPdfField extends StatelessWidget {
  final String? pdfName;
  final String prefix;
  final ValueChanged<String?> onChanged;
  const _OptionalPdfField({
    required this.pdfName,
    required this.prefix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final stamp = DateTime.now().millisecondsSinceEpoch;
            final remote = SupabaseDatabaseService.instance;
            if (!remote.isReady) {
              onChanged('${prefix}_$stamp.pdf');
              _toast(context, 'PDF agregado en modo demo.');
              return;
            }

            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: const ['pdf'],
              withData: true,
            );
            final file = result?.files.single;
            final bytes = file?.bytes;
            if (file == null || bytes == null) return;

            final safeName = file.name.replaceAll(
              RegExp(r'[^A-Za-z0-9_.-]'),
              '_',
            );
            final path = '$prefix/$stamp-$safeName';
            try {
              final uploaded = await remote.uploadDocument(
                path: path,
                bytes: bytes,
              );
              onChanged(uploaded);
              if (context.mounted) {
                _toast(context, 'PDF subido a Supabase Storage.');
              }
            } catch (_) {
              if (context.mounted) {
                _toast(context, 'No se pudo subir el PDF a Supabase.');
              }
            }
          },
          icon: const Icon(Icons.picture_as_pdf),
          label: Text(pdfName == null ? 'Agregar PDF opcional' : 'Cambiar PDF'),
        ),
        if (pdfName != null)
          InputChip(
            avatar: const Icon(Icons.picture_as_pdf, size: 18),
            label: Text(pdfName!),
            onDeleted: () => onChanged(null),
          ),
      ],
    );
  }
}

class _UserForm extends StatefulWidget {
  final AppUser? initial;
  final UserRole? forcedRole;
  const _UserForm({this.initial, this.forcedRole});
  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  late UserRole role = widget.initial?.role == UserRole.empresa
      ? UserRole.estudiante
      : widget.forcedRole ?? widget.initial?.role ?? UserRole.estudiante;
  late final name = TextEditingController(text: widget.initial?.name ?? '');
  late final email = TextEditingController(text: widget.initial?.email ?? '');
  late final password = TextEditingController(
    text: widget.initial?.password ?? '',
  );
  late Student? selectedStudent = _studentById(widget.initial?.studentId);
  late Company? selectedCompany = _companyById(widget.initial?.companyId);

  void _setRole(UserRole value) {
    setState(() {
      role = value;
      selectedStudent = null;
      selectedCompany = null;
      name.clear();
      email.clear();
    });
  }

  void _pickStudent(Student student) {
    setState(() {
      selectedStudent = student;
      name.text = student.name;
      email.text = student.email.isEmpty
          ? '${student.code}@student.practicapp.pe'
          : student.email;
    });
  }

  void _pickCompany(Company company) {
    setState(() {
      selectedCompany = company;
      name.text = company.contact.isEmpty
          ? 'Encargado ${company.name}'
          : company.contact;
      email.text = company.email;
    });
  }

  @override
  Widget build(BuildContext context) => _FormScaffold(
    title: widget.initial == null ? 'Crear usuario' : 'Editar usuario',
    children: [
      DropdownButtonFormField<UserRole>(
        value: role,
        items: UserRole.values
            .where((r) => r != UserRole.empresa)
            .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
            .toList(),
        onChanged: widget.forcedRole == null
            ? (r) => _setRole(r ?? role)
            : null,
        decoration: const InputDecoration(labelText: 'Rol'),
      ),
      if (role == UserRole.estudiante)
        _PickerField<Student>(
          label: 'Estudiante existente',
          value: selectedStudent,
          items: LocalDataService.instance.getStudents(),
          labelOf: (s) => '${s.name} - ${s.code}',
          onChanged: _pickStudent,
        ),
      if (role == UserRole.encargado)
        _PickerField<Company>(
          label: 'Empresa asignada',
          value: selectedCompany,
          items: LocalDataService.instance.getCompanies(),
          labelOf: (c) => c.name,
          onChanged: _pickCompany,
        ),
      TextField(
        controller: name,
        decoration: const InputDecoration(labelText: 'Nombres completos'),
      ),
      TextField(
        controller: email,
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      TextField(
        controller: password,
        decoration: const InputDecoration(labelText: 'Contraseña'),
      ),
    ],
    saveLabel: 'Crear usuario',
    onSave: () {
      if (name.text.trim().isEmpty) {
        _toast(context, 'Ingresa los nombres completos.');
        return;
      }
      if (role == UserRole.estudiante && selectedStudent == null) {
        _toast(context, 'Selecciona el estudiante existente.');
        return;
      }
      if (role == UserRole.encargado && selectedCompany == null) {
        _toast(context, 'Selecciona la empresa del encargado.');
        return;
      }
      if (email.text.trim().isEmpty || !email.text.contains('@')) {
        _toast(context, 'Ingresa un email válido.');
        return;
      }
      if (widget.initial == null && password.text.trim().isEmpty) {
        _toast(context, 'Ingresa una contraseña.');
        return;
      }
      Navigator.pop(
        context,
        AppUser(
          id: widget.initial?.id ?? '',
          name: name.text.trim(),
          email: email.text.trim(),
          role: role,
          avatar: 'US',
          password: password.text.trim(),
          companyId: role == UserRole.encargado ? selectedCompany?.id : null,
          studentId: role == UserRole.estudiante ? selectedStudent?.id : null,
        ),
      );
    },
  );
}

class _FormScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final String saveLabel;
  final VoidCallback onSave;
  const _FormScaffold({
    required this.title,
    required this.children,
    required this.saveLabel,
    required this.onSave,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            ...children.expand((w) => [w, const SizedBox(height: 12)]),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 340;
                final cancel = OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                );
                final save = FilledButton(
                  onPressed: onSave,
                  child: Text(saveLabel, textAlign: TextAlign.center),
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [save, const SizedBox(height: 8), cancel],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: cancel),
                    const SizedBox(width: 10),
                    Expanded(child: save),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  const _PickerField({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });
  @override
  State<_PickerField<T>> createState() => _PickerFieldState<T>();
}

class _PickerFieldState<T> extends State<_PickerField<T>> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final shown = q.isEmpty
        ? widget.items.take(3).toList()
        : _filter(widget.items, q, widget.labelOf);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => q = v),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: shown
              .map(
                (item) => ChoiceChip(
                  label: Text(widget.labelOf(item)),
                  selected: item == widget.value,
                  onSelected: (_) => widget.onChanged(item),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;
  const _DateButton({
    required this.label,
    required this.date,
    required this.onPick,
  });
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );
      if (picked != null) onPick(picked);
    },
    icon: const Icon(Icons.calendar_month),
    label: Text('$label\n${_date(date)}'),
  );
}

class _Page extends StatelessWidget {
  final String? title;
  final Widget? search;
  final List<Widget> children;
  const _Page({this.title, this.search, required this.children});
  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      if (title != null)
        Text(
          title!,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
      if (search != null) ...[const SizedBox(height: 12), search!],
      const SizedBox(height: 12),
      ...children.expand((w) => [w, const SizedBox(height: 12)]),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: content.length,
      itemBuilder: (context, index) =>
          _Reveal(delay: math.min(index * 22, 180), child: content[index]),
    );
  }
}

class _Search extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hint;
  const _Search({required this.onChanged, required this.hint});

  @override
  State<_Search> createState() => _SearchState();
}

class _SearchState extends State<_Search> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    textInputAction: TextInputAction.search,
    autocorrect: false,
    enableSuggestions: false,
    onChanged: widget.onChanged,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search),
      hintText: widget.hint,
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Limpiar busqueda',
              onPressed: () {
                controller.clear();
                widget.onChanged('');
                setState(() {});
              },
              icon: const Icon(Icons.close),
            ),
    ),
  );
}

class _Reveal extends StatelessWidget {
  final Widget child;
  final int delay;
  const _Reveal({required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  const _PressableScale({
    required this.child,
    this.onTap,
    required this.borderRadius,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool pressed = false;

  void _setPressed(bool value) {
    if (pressed == value) return;
    setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: pressed ? .97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        borderRadius: widget.borderRadius,
        child: InkWell(
          borderRadius: widget.borderRadius,
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PracticeTile extends StatelessWidget {
  final Practice practice;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _PracticeTile({
    required this.practice,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) => _Card(
    title: practice.student.name,
    icon: Icons.description,
    action: _Pill(practice.status.label, practice.status.color),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          practice.company.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        Text(
          practice.status == PracticeStatus.completed
              ? '${_date(practice.startDate)} - ${_date(practice.endDate)}'
              : 'Inicio: ${_date(practice.startDate)} - Fin: al completar horas',
        ),
        Text('Módulo de práctica: ${practice.practiceModule}'),
        Text('Turno: ${practice.shift}'),
        Text(
          '${practice.accumulatedHours}/${practice.requiredHours} horas - ${practice.remainingHours}h restantes',
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: practice.progress),
        const SizedBox(height: 8),
        Text(practice.learningObjective),
        if (onEdit != null || onDelete != null)
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              children: [
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
                  ),
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
  @override
  Widget build(BuildContext context) => _PressableScale(
    borderRadius: BorderRadius.circular(20),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, maxLines: 5, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;
  const _Card({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });
  @override
  Widget build(BuildContext context) => _PressableScale(
    borderRadius: BorderRadius.circular(20),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    ),
  );
}

class _Welcome extends StatefulWidget {
  final AppUser user;
  const _Welcome({required this.user});

  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Container(
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + (.35 * t), -1),
              end: Alignment(1 - (.2 * t), 1),
              colors: [user.role.color, const Color(0xFF312E81)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: user.role.color.withValues(alpha: .18),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -38 + (26 * t),
                top: -45,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .10),
                  ),
                ),
              ),
              Positioned(
                left: -70 + (34 * (1 - t)),
                bottom: -74,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .07),
                  ),
                ),
              ),
              Row(
                children: [
                  _Avatar(user: user, light: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bienvenido de vuelta',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const Text(
                          'Panel de Control - EFSRT',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _Stat(this.label, this.value, this.icon, this.color, {this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    child: _PressableScale(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ),
  );
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  const _Mini(this.label, this.value);
  @override
  Widget build(BuildContext context) => _PressableScale(
    borderRadius: BorderRadius.circular(20),
    child: Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: Tween<double>(begin: .88, end: 1).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Text(
                  value,
                  key: ValueKey(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Progress extends StatelessWidget {
  final Practice practice;
  const _Progress(this.practice);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                practice.student.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text('${(practice.progress * 100).round()}%'),
          ],
        ),
        LinearProgressIndicator(value: practice.progress),
      ],
    ),
  );
}

class _PdfButton extends StatelessWidget {
  final String label;
  final List<String> lines;
  final bool enabled;
  const _PdfButton({
    required this.label,
    required this.lines,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: enabled
        ? () async {
            await PdfReportService.createAndSaveReport(
              fileName: 'practicapp_$label',
              title: label,
              lines: lines,
            );
            if (context.mounted) {
              _toast(context, 'PDF guardado o listo para compartir.');
            }
          }
        : null,
    icon: const Icon(Icons.picture_as_pdf),
    label: Text(label),
  );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(.12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
    ),
  );
}

class _Avatar extends StatelessWidget {
  final AppUser user;
  final bool light;
  const _Avatar({required this.user, this.light = false});
  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundColor: light ? Colors.white24 : user.role.color.withOpacity(.12),
    foregroundColor: light ? Colors.white : user.role.color,
    child: Text(
      user.avatar,
      style: const TextStyle(fontWeight: FontWeight.w900),
    ),
  );
}

List<T> _filter<T>(List<T> items, String query, String Function(T) textOf) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return items;
  return items.where((item) => textOf(item).toLowerCase().contains(q)).toList();
}

Company? _companyById(String? id) {
  if (id == null) return null;
  for (final company in LocalDataService.instance.getCompanies()) {
    if (company.id == id) return company;
  }
  return null;
}

Student? _studentById(String? id) {
  if (id == null) return null;
  for (final student in LocalDataService.instance.getStudents()) {
    if (student.id == id) return student;
  }
  return null;
}

Future<Position?> _currentDevicePosition() async {
  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
  } catch (_) {
    return null;
  }
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _time(DateTime d) {
  final hour = d.hour == 0
      ? 12
      : d.hour > 12
      ? d.hour - 12
      : d.hour;
  final minute = d.minute.toString().padLeft(2, '0');
  final suffix = d.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}
