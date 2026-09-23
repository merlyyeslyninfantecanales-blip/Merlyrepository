import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { supervisor, encargado, estudiante, empresa }

extension UserRoleInfo on UserRole {
  String get label => switch (this) {
    UserRole.supervisor => 'Supervisor',
    UserRole.encargado => 'Encargado',
    UserRole.estudiante => 'Estudiante',
    UserRole.empresa => 'Empresa',
  };

  String get routeName => name;

  IconData get icon => switch (this) {
    UserRole.supervisor => Icons.engineering,
    UserRole.encargado => Icons.work,
    UserRole.estudiante => Icons.school,
    UserRole.empresa => Icons.business,
  };

  Color get color => switch (this) {
    UserRole.supervisor => const Color(0xFF6D28D9),
    UserRole.encargado => const Color(0xFFF97316),
    UserRole.estudiante => const Color(0xFF2563EB),
    UserRole.empresa => const Color(0xFF059669),
  };
}

UserRole? userRoleFromRoute(String value) {
  final normalized = value.toLowerCase();
  for (final role in UserRole.values) {
    if (role.name == normalized || role.label.toLowerCase() == normalized) {
      return role;
    }
  }
  return null;
}

enum PracticeStatus { active, completed, pending, cancelled }

extension PracticeStatusInfo on PracticeStatus {
  String get label => switch (this) {
    PracticeStatus.active => 'Activa',
    PracticeStatus.completed => 'Completada',
    PracticeStatus.pending => 'Pendiente',
    PracticeStatus.cancelled => 'Cancelada',
  };

  Color get color => switch (this) {
    PracticeStatus.active => const Color(0xFF2563EB),
    PracticeStatus.completed => const Color(0xFF059669),
    PracticeStatus.pending => const Color(0xFFF59E0B),
    PracticeStatus.cancelled => const Color(0xFFDC2626),
  };
}

enum AttendanceStatus { present, absent, late, permission }

extension AttendanceStatusInfo on AttendanceStatus {
  String get label => switch (this) {
    AttendanceStatus.present => 'Presente',
    AttendanceStatus.absent => 'Ausencia',
    AttendanceStatus.late => 'Tardanza',
    AttendanceStatus.permission => 'Justificación',
  };
}

enum VacancyStatus { open, occupied, closed }

extension VacancyStatusInfo on VacancyStatus {
  String get label => switch (this) {
    VacancyStatus.open => 'Abierta',
    VacancyStatus.occupied => 'Ocupada',
    VacancyStatus.closed => 'Cerrada',
  };
}

class AppUser {
  String id;
  String name;
  String email;
  UserRole role;
  String avatar;
  String password;
  String? companyId;
  String? studentId;
  String? authUserId;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.avatar,
    required this.password,
    this.companyId,
    this.studentId,
    this.authUserId,
  });
}

class Student {
  String id;
  String name;
  String code;
  String email;
  String phone;
  String program;
  String semester;

  Student({
    required this.id,
    required this.name,
    required this.code,
    required this.email,
    required this.phone,
    required this.program,
    this.semester = '',
  });
}

class Company {
  String id;
  String name;
  String ruc;
  String address;
  String contact;
  String phone;
  String email;
  double latitude;
  double longitude;
  int? _totalVacancies;

  Company({
    required this.id,
    required this.name,
    required this.ruc,
    required this.address,
    required this.contact,
    required this.phone,
    required this.email,
    required this.latitude,
    required this.longitude,
    int? totalVacancies,
  }) : _totalVacancies = totalVacancies ?? 0;

  int get totalVacancies => _totalVacancies ?? 0;
  set totalVacancies(int value) => _totalVacancies = value;
}

class Practice {
  String id;
  Student student;
  Company company;
  String? _practiceModule;
  String? _shift;
  DateTime startDate;
  DateTime endDate;
  int requiredHours;
  int accumulatedHours;
  PracticeStatus status;
  String learningObjective;
  List<String> completedObjectives;
  List<String> pendingObjectives;
  List<String> monthlyReports;
  bool certificateIssued;

  Practice({
    required this.id,
    required this.student,
    required this.company,
    String? practiceModule,
    String? shift,
    required this.startDate,
    required this.endDate,
    required this.requiredHours,
    required this.accumulatedHours,
    required this.status,
    required this.learningObjective,
    required this.completedObjectives,
    required this.pendingObjectives,
    required this.monthlyReports,
    this.certificateIssued = false,
  }) : _practiceModule = practiceModule ?? 'I',
       _shift = shift ?? 'Día completo';

  String get practiceModule => _practiceModule ?? 'I';
  set practiceModule(String value) => _practiceModule = value;

  String get shift => _shift ?? 'Día completo';
  set shift(String value) => _shift = value;

  double get progress {
    if (requiredHours == 0) return 0;
    return (accumulatedHours / requiredHours).clamp(0, 1).toDouble();
  }

  int get remainingHours =>
      (requiredHours - accumulatedHours).clamp(0, requiredHours).toInt();
}

class Attendance {
  String id;
  String practiceId;
  DateTime date;
  AttendanceStatus status;
  double hours;
  String notes;
  double latitude;
  double longitude;

  Attendance({
    required this.id,
    required this.practiceId,
    required this.date,
    required this.status,
    required this.hours,
    required this.notes,
    required this.latitude,
    required this.longitude,
  });
}

class AttendanceSession {
  String practiceId;
  DateTime date;
  bool gpsVerified;
  DateTime? checkInTime;
  double latitude;
  double longitude;

  AttendanceSession({
    required this.practiceId,
    required this.date,
    required this.gpsVerified,
    required this.latitude,
    required this.longitude,
    this.checkInTime,
  });
}

class Evaluation {
  String id;
  String practiceId;
  String title;
  int score;
  String comment;
  String performance;
  String? pdfName;

  Evaluation({
    required this.id,
    required this.practiceId,
    required this.title,
    required this.score,
    required this.comment,
    this.performance = '',
    this.pdfName,
  });
}

class TrackingRecord {
  String id;
  String practiceId;
  String title;
  int progress;
  String completedObjectives;
  String pendingObjectives;
  String monthlyReport;
  String? pdfName;

  TrackingRecord({
    required this.id,
    required this.practiceId,
    required this.title,
    required this.progress,
    required this.completedObjectives,
    required this.pendingObjectives,
    required this.monthlyReport,
    this.pdfName,
  });
}

class Vacancy {
  String id;
  Company company;
  String position;
  String description;
  String? _requirements;
  int requiredHours;
  String schedule;
  String? _shift;
  VacancyStatus status;
  Student? student;

  Vacancy({
    required this.id,
    required this.company,
    required this.position,
    required this.description,
    String? requirements,
    required this.requiredHours,
    required this.schedule,
    String? shift,
    required this.status,
    this.student,
  }) : _requirements = requirements ?? '',
       _shift = shift ?? 'Día completo';

  String get requirements => _requirements ?? '';
  set requirements(String value) => _requirements = value;

  String get shift => _shift ?? 'Día completo';
  set shift(String value) => _shift = value;
}

class LocalDataService {
  LocalDataService._();

  static final LocalDataService instance = LocalDataService._();

  late final List<Student> _students = _seedStudents();
  late final List<Company> _companies = _seedCompanies();
  late final List<AppUser> _users = _seedUsers();
  late final List<Practice> _practices = _seedPractices();
  late final List<Vacancy> _vacancies = _seedVacancies();
  late final Map<String, List<Attendance>> _attendanceRecords =
      _seedAttendanceRecords();
  final Map<String, AttendanceSession> _openAttendanceSessions = {};
  final Map<String, List<Evaluation>> _extraEvaluations = {};
  final Map<String, Evaluation> _editedEvaluations = {};
  final Map<String, List<TrackingRecord>> _extraTrackingRecords = {};
  final Map<String, TrackingRecord> _editedTrackingRecords = {};
  bool _usingRemoteEvaluations = false;
  bool _usingRemoteTracking = false;

  static const programs = [
    'Arquitectura de plataformas y servicios de tecnologías de la información',
    'Enfermería técnica',
    'Mecatrónica automotriz',
    'Acuicultura y procesamiento pesquero',
  ];

  static const practiceModules = ['I', 'II', 'III'];
  static const _openAttendanceSessionsKey =
      'practicapp_open_attendance_sessions';

  List<AppUser> getUsers() => List.unmodifiable(_users);
  List<AppUser> getUsersByRole(UserRole role) =>
      _users.where((user) => user.role == role).toList();
  List<Student> getStudents() => List.unmodifiable(_students);
  List<Company> getCompanies() => List.unmodifiable(_companies);
  List<Practice> getPractices() => List.unmodifiable(_practices);
  List<Vacancy> getVacancies() => List.unmodifiable(_vacancies);

  void replaceStudents(List<Student> students) {
    _students
      ..clear()
      ..addAll(students);
  }

  void replaceCompanies(List<Company> companies) {
    _companies
      ..clear()
      ..addAll(companies);
  }

  void replacePractices(List<Practice> practices) {
    _practices
      ..clear()
      ..addAll(practices);
  }

  void replaceAttendanceRecords(Map<String, List<Attendance>> records) {
    _attendanceRecords
      ..clear()
      ..addAll(records);
  }

  void replaceEvaluations(Map<String, List<Evaluation>> evaluations) {
    _extraEvaluations
      ..clear()
      ..addAll(evaluations);
    _editedEvaluations.clear();
    _usingRemoteEvaluations = true;
  }

  void replaceTrackingRecords(Map<String, List<TrackingRecord>> records) {
    _extraTrackingRecords
      ..clear()
      ..addAll(records);
    _editedTrackingRecords.clear();
    _usingRemoteTracking = true;
  }

  void replaceVacancies(List<Vacancy> vacancies) {
    _vacancies
      ..clear()
      ..addAll(vacancies);
  }

  void replaceUsers(List<AppUser> users) {
    _users
      ..clear()
      ..addAll(users);
  }

  List<Vacancy> getVacanciesForUser(AppUser user) {
    if (user.role != UserRole.empresa) return getVacancies();
    return _vacancies.where((v) => v.company.email == user.email).toList();
  }

  List<Practice> getPracticesForUser(AppUser user) {
    return switch (user.role) {
      UserRole.estudiante => _getPracticesForStudentUser(user),
      UserRole.encargado => _getPracticesForCompanyUser(user),
      _ => getPractices(),
    };
  }

  List<Practice> _getPracticesForCompanyUser(AppUser user) {
    final company = getCompanyForUser(user);
    if (company == null) return const [];
    return _practices.where((p) => p.company.id == company.id).toList();
  }

  List<Practice> _getPracticesForStudentUser(AppUser user) {
    if (user.studentId != null) {
      final byStudentId = _practices
          .where((p) => p.student.id == user.studentId)
          .toList();
      if (byStudentId.isNotEmpty) return byStudentId;
    }

    final byEmail = _practices
        .where((p) => p.student.email.toLowerCase() == user.email.toLowerCase())
        .toList();
    if (byEmail.isNotEmpty) return byEmail;

    final userName = user.name.trim().toLowerCase();
    return _practices.where((p) {
      final studentName = p.student.name.trim().toLowerCase();
      return studentName == userName || studentName.startsWith('$userName ');
    }).toList();
  }

  Practice? getPracticeById(String id) {
    for (final practice in _practices) {
      if (practice.id == id) return practice;
    }
    return null;
  }

  List<Attendance> getAttendances(String practiceId) =>
      List.unmodifiable(_attendanceRecords[practiceId] ?? const []);

  AttendanceSession? getOpenAttendanceSession(String practiceId) =>
      _openAttendanceSessions[practiceId];

  Future<void> restoreOpenAttendanceSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_openAttendanceSessionsKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _openAttendanceSessions
        ..clear()
        ..addEntries(
          decoded
              .whereType<Map>()
              .map((item) => _attendanceSessionFromStorage(item))
              .whereType<AttendanceSession>()
              .map((session) => MapEntry(session.practiceId, session)),
        );
    } catch (_) {
      await prefs.remove(_openAttendanceSessionsKey);
    }
  }

  AttendanceSession verifyAttendanceGps(
    String practiceId, {
    double? latitude,
    double? longitude,
  }) {
    final fallback = _fakeAttendanceLocation(practiceId);
    final resolvedLatitude = latitude ?? fallback.$1;
    final resolvedLongitude = longitude ?? fallback.$2;
    final session = _openAttendanceSessions.putIfAbsent(
      practiceId,
      () => AttendanceSession(
        practiceId: practiceId,
        date: DateTime.now(),
        gpsVerified: true,
        latitude: resolvedLatitude,
        longitude: resolvedLongitude,
      ),
    );
    session.gpsVerified = true;
    session.latitude = resolvedLatitude;
    session.longitude = resolvedLongitude;
    _queueOpenAttendanceSessionsSave();
    return session;
  }

  AttendanceSession confirmAttendanceEntry(String practiceId) {
    final session =
        _openAttendanceSessions[practiceId] ?? verifyAttendanceGps(practiceId);
    session.gpsVerified = true;
    session.checkInTime ??= DateTime.now();
    _queueOpenAttendanceSessionsSave();
    return session;
  }

  Attendance completeAttendanceExit(String practiceId) {
    final session =
        _openAttendanceSessions[practiceId] ??
        confirmAttendanceEntry(practiceId);
    final checkIn = session.checkInTime ?? DateTime.now();
    final checkOut = DateTime.now();
    final hours = checkOut.difference(checkIn).inMinutes / 60;
    final attendance = Attendance(
      id: 'A$practiceId-${checkOut.millisecondsSinceEpoch}',
      practiceId: practiceId,
      date: checkOut,
      status: AttendanceStatus.present,
      hours: hours <= 0 ? .1 : double.parse(hours.toStringAsFixed(2)),
      notes:
          'Entrada ${_formatTime(checkIn)} - Salida ${_formatTime(checkOut)} - GPS Verificado',
      latitude: session.latitude,
      longitude: session.longitude,
    );
    _attendanceRecords.putIfAbsent(practiceId, () => []).insert(0, attendance);
    _openAttendanceSessions.remove(practiceId);
    _queueOpenAttendanceSessionsSave();

    final practice = getPracticeById(practiceId);
    if (practice != null && practice.status == PracticeStatus.active) {
      practice.accumulatedHours += attendance.hours.round();
      if (practice.progress >= 1) {
        practice.status = PracticeStatus.completed;
        practice.endDate = checkOut;
      }
    }
    return attendance;
  }

  List<Evaluation> getEvaluations(String practiceId) {
    if (_usingRemoteEvaluations) {
      return List.unmodifiable(_extraEvaluations[practiceId] ?? const []);
    }
    final base = [
      Evaluation(
        id: 'E$practiceId-1',
        practiceId: practiceId,
        title: 'Evaluación parcial',
        score: 86,
        comment: 'Buen avance y responsabilidad en tareas asignadas.',
        performance: 'Responsabilidad y adaptación',
      ),
      Evaluation(
        id: 'E$practiceId-2',
        practiceId: practiceId,
        title: 'Desempeño en empresa',
        score: 78,
        comment: 'Debe reforzar puntualidad y documentación.',
        performance: 'Desempeño operativo',
      ),
      if (getPracticeById(practiceId)?.status == PracticeStatus.completed)
        Evaluation(
          id: 'E$practiceId-final',
          practiceId: practiceId,
          title: 'Evaluación final',
          score: 88,
          comment: 'Práctica culminada con resultado aprobatorio.',
          performance: 'Cierre satisfactorio',
        ),
    ];
    return [
      ...base.map(
        (evaluation) => _editedEvaluations[evaluation.id] ?? evaluation,
      ),
      ...?_extraEvaluations[practiceId],
    ];
  }

  List<TrackingRecord> getTrackingRecords(String practiceId) {
    final practice = getPracticeById(practiceId);
    if (practice == null) return const [];
    if (_usingRemoteTracking) {
      return List.unmodifiable(_extraTrackingRecords[practiceId] ?? const []);
    }
    final base = TrackingRecord(
      id: 'T$practiceId-base',
      practiceId: practiceId,
      title: 'Seguimiento general',
      progress: (practice.progress * 100).round(),
      completedObjectives: practice.completedObjectives.join(', '),
      pendingObjectives: practice.pendingObjectives.join(', '),
      monthlyReport: practice.monthlyReports.join('\n'),
    );
    return [
      _editedTrackingRecords[base.id] ?? base,
      ...?_extraTrackingRecords[practiceId],
    ];
  }

  Student addStudent({
    required String name,
    required String code,
    required String phone,
    required String program,
    required String semester,
  }) {
    final student = Student(
      id: 'S${(_students.length + 1).toString().padLeft(3, '0')}',
      name: name,
      code: code,
      email: '${name.toLowerCase().replaceAll(' ', '.')}@student.edu.pe',
      phone: phone,
      program: program,
      semester: semester,
    );
    _students.add(student);
    return student;
  }

  void updateStudent(Student student) {}

  void deleteStudent(String id) {
    final removedPracticeIds = _practices
        .where((practice) => practice.student.id == id)
        .map((practice) => practice.id)
        .toList();
    _students.removeWhere((student) => student.id == id);
    _practices.removeWhere((practice) => practice.student.id == id);
    for (final practiceId in removedPracticeIds) {
      _attendanceRecords.remove(practiceId);
      _openAttendanceSessions.remove(practiceId);
      _extraEvaluations.remove(practiceId);
    }
    _queueOpenAttendanceSessionsSave();
  }

  Company addCompany({
    required String name,
    required String ruc,
    required String phone,
    required String address,
    required String contact,
    required String email,
    required double latitude,
    required double longitude,
    required int totalVacancies,
  }) {
    final company = Company(
      id: 'C${(_companies.length + 1).toString().padLeft(3, '0')}',
      name: name,
      ruc: ruc,
      address: address,
      contact: contact,
      phone: phone,
      email: email,
      latitude: latitude,
      longitude: longitude,
      totalVacancies: totalVacancies,
    );
    _companies.add(company);
    return company;
  }

  void updateCompany(Company company) {}

  void deleteCompany(String id) {
    _companies.removeWhere((company) => company.id == id);
    _practices.removeWhere((practice) => practice.company.id == id);
    _vacancies.removeWhere((vacancy) => vacancy.company.id == id);
  }

  Company? getCompanyForUser(AppUser user) {
    if (user.companyId != null) {
      for (final company in _companies) {
        if (company.id == user.companyId) return company;
      }
    }
    for (final company in _companies) {
      if (company.email == user.email || company.name == user.name) {
        return company;
      }
    }
    return null;
  }

  AppUser addUser({
    required String name,
    required String email,
    required UserRole role,
    required String password,
    String? companyId,
    String? studentId,
  }) {
    final id = 'U${(_users.length + 1).toString().padLeft(3, '0')}';
    final initials = _initials(name);
    final user = AppUser(
      id: id,
      name: name,
      email: email,
      role: role,
      avatar: initials,
      password: password,
      companyId: companyId,
      studentId: studentId,
    );
    _users.add(user);
    return user;
  }

  void updateUser(AppUser user) {}

  void deleteUser(String id) {
    _users.removeWhere((user) => user.id == id);
  }

  Practice addPractice({
    required Student student,
    required Company company,
    required String practiceModule,
    required String shift,
    required DateTime startDate,
    required DateTime endDate,
    required int requiredHours,
    required PracticeStatus status,
    required String learningObjective,
  }) {
    final practice = Practice(
      id: 'P${(_practices.length + 1).toString().padLeft(3, '0')}',
      student: student,
      company: company,
      practiceModule: practiceModule,
      shift: shift,
      startDate: startDate,
      endDate: endDate,
      requiredHours: requiredHours,
      accumulatedHours: 0,
      status: status,
      learningObjective: learningObjective,
      completedObjectives: const ['Puntualidad', 'Uso de herramientas'],
      pendingObjectives: const ['Informe técnico', 'Entrega final'],
      monthlyReports: const [
        'Marzo: adaptación inicial y reconocimiento de actividades.',
        'Abril: avance operativo y primeras entregas supervisadas.',
      ],
    );
    _practices.insert(0, practice);
    return practice;
  }

  void updatePractice(Practice practice) {}

  void deletePractice(String id) {
    _practices.removeWhere((practice) => practice.id == id);
    _attendanceRecords.remove(id);
    _openAttendanceSessions.remove(id);
    _extraEvaluations.remove(id);
    _extraTrackingRecords.remove(id);
    _queueOpenAttendanceSessionsSave();
  }

  AttendanceSession? _attendanceSessionFromStorage(Map item) {
    final practiceId = item['practiceId'];
    final date = DateTime.tryParse('${item['date'] ?? ''}');
    final checkIn = DateTime.tryParse('${item['checkInTime'] ?? ''}');
    final latitude = _readDouble(item['latitude']);
    final longitude = _readDouble(item['longitude']);
    if (practiceId is! String ||
        practiceId.isEmpty ||
        date == null ||
        latitude == null ||
        longitude == null) {
      return null;
    }
    return AttendanceSession(
      practiceId: practiceId,
      date: date,
      gpsVerified: item['gpsVerified'] == true,
      latitude: latitude,
      longitude: longitude,
      checkInTime: checkIn,
    );
  }

  double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  void _queueOpenAttendanceSessionsSave() {
    unawaited(_saveOpenAttendanceSessions());
  }

  Future<void> _saveOpenAttendanceSessions() async {
    final prefs = await SharedPreferences.getInstance();
    if (_openAttendanceSessions.isEmpty) {
      await prefs.remove(_openAttendanceSessionsKey);
      return;
    }
    final payload = _openAttendanceSessions.values
        .map(
          (session) => {
            'practiceId': session.practiceId,
            'date': session.date.toIso8601String(),
            'gpsVerified': session.gpsVerified,
            'checkInTime': session.checkInTime?.toIso8601String(),
            'latitude': session.latitude,
            'longitude': session.longitude,
          },
        )
        .toList();
    await prefs.setString(_openAttendanceSessionsKey, jsonEncode(payload));
  }

  Evaluation addEvaluation({
    required String practiceId,
    required String title,
    required int score,
    required String comment,
    required String performance,
    String? pdfName,
  }) {
    final evaluation = Evaluation(
      id: 'E$practiceId-${DateTime.now().millisecondsSinceEpoch}',
      practiceId: practiceId,
      title: title,
      score: score.clamp(0, 100).toInt(),
      comment: comment,
      performance: performance,
      pdfName: pdfName,
    );
    _extraEvaluations.putIfAbsent(practiceId, () => []).insert(0, evaluation);
    return evaluation;
  }

  void updateEvaluation(Evaluation evaluation) {
    final extras = _extraEvaluations[evaluation.practiceId];
    final index = extras?.indexWhere((item) => item.id == evaluation.id) ?? -1;
    if (extras != null && index >= 0) {
      extras[index] = evaluation;
    } else {
      _editedEvaluations[evaluation.id] = evaluation;
    }
  }

  TrackingRecord addTrackingRecord({
    required String practiceId,
    required String title,
    required int progress,
    required String completedObjectives,
    required String pendingObjectives,
    required String monthlyReport,
    String? pdfName,
  }) {
    final record = TrackingRecord(
      id: 'T$practiceId-${DateTime.now().millisecondsSinceEpoch}',
      practiceId: practiceId,
      title: title,
      progress: progress.clamp(0, 100).toInt(),
      completedObjectives: completedObjectives,
      pendingObjectives: pendingObjectives,
      monthlyReport: monthlyReport,
      pdfName: pdfName,
    );
    _extraTrackingRecords.putIfAbsent(practiceId, () => []).insert(0, record);
    return record;
  }

  void updateTrackingRecord(TrackingRecord record) {
    final extras = _extraTrackingRecords[record.practiceId];
    final index = extras?.indexWhere((item) => item.id == record.id) ?? -1;
    if (extras != null && index >= 0) {
      extras[index] = record;
    } else {
      _editedTrackingRecords[record.id] = record;
    }
  }

  Vacancy addVacancy({
    required Company company,
    required String position,
    required String description,
    required String requirements,
    required int requiredHours,
    required String schedule,
    required String shift,
  }) {
    final vacancy = Vacancy(
      id: 'V${(_vacancies.length + 1).toString().padLeft(3, '0')}',
      company: company,
      position: position,
      description: description,
      requirements: requirements,
      requiredHours: requiredHours.clamp(160, 480).toInt(),
      schedule: schedule,
      shift: shift,
      status: VacancyStatus.open,
    );
    _vacancies.insert(0, vacancy);
    return vacancy;
  }

  void updateVacancy(Vacancy vacancy) {}

  void deleteVacancy(String id) {
    _vacancies.removeWhere((vacancy) => vacancy.id == id);
  }

  void closeVacancy(String id) {
    final vacancy = _vacancies.firstWhere((item) => item.id == id);
    vacancy.status = VacancyStatus.closed;
  }

  void reopenVacancy(String id) {
    final vacancy = _vacancies.firstWhere((item) => item.id == id);
    vacancy.status = VacancyStatus.open;
    vacancy.student = null;
  }

  void addHours(String practiceId, int hours) {
    final practice = _practices.firstWhere((item) => item.id == practiceId);
    practice.accumulatedHours += hours;
    if (practice.progress >= 1) {
      practice.status = PracticeStatus.completed;
      practice.endDate = DateTime.now();
    }
  }

  void closePractice(String practiceId) {
    final practice = _practices.firstWhere((item) => item.id == practiceId);
    practice.status = PracticeStatus.completed;
    practice.accumulatedHours = practice.requiredHours;
    practice.endDate = DateTime.now();
    practice.certificateIssued = true;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final value = parts
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();
    return value.isEmpty ? 'US' : value;
  }

  (double, double) _fakeAttendanceLocation(String practiceId) {
    final practice = getPracticeById(practiceId);
    final now = DateTime.now();
    final offset = (now.second + now.minute) * .00001;
    return (
      (practice?.company.latitude ?? -3.6817) + offset,
      (practice?.company.longitude ?? -80.6760) - offset,
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
        ? time.hour - 12
        : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  Map<String, List<Attendance>> _seedAttendanceRecords() {
    final records = <String, List<Attendance>>{};
    for (final practice in _practices) {
      records[practice.id] = _demoAttendances(practice);
    }
    return records;
  }

  List<Attendance> _demoAttendances(Practice practice) {
    final today = DateTime.now();
    return List.generate(6, (index) {
      final day = today.subtract(Duration(days: index + 1));
      final status = index == 2
          ? AttendanceStatus.late
          : index == 4
          ? AttendanceStatus.absent
          : AttendanceStatus.present;
      return Attendance(
        id: 'A${practice.id}$index',
        practiceId: practice.id,
        date: day,
        status: status,
        hours: status == AttendanceStatus.absent
            ? 0
            : status == AttendanceStatus.late
            ? 5.5
            : 8,
        notes: status.label,
        latitude: practice.company.latitude + (index * .00013),
        longitude: practice.company.longitude - (index * .00009),
      );
    });
  }

  List<AppUser> _seedUsers() => [
    AppUser(
      id: 'U001',
      name: 'Dr. Carlos Mendoza',
      email: 'cmendoza@iestp.edu.pe',
      role: UserRole.supervisor,
      avatar: 'CM',
      password: 'supervisor2024',
    ),
    AppUser(
      id: 'U002',
      name: 'Lic. Ana Garcia',
      email: 'ana.garcia@techsolutions.com',
      role: UserRole.encargado,
      avatar: 'AG',
      password: 'encargado2024',
      companyId: 'C001',
    ),
    AppUser(
      id: 'U003',
      name: 'Juan Perez',
      email: 'juan.perez@student.edu.pe',
      role: UserRole.estudiante,
      avatar: 'JP',
      password: 'estudiante123',
    ),
    AppUser(
      id: 'U005',
      name: 'Lic. Laura Martinez',
      email: 'laura.martinez@corpnorte.com',
      role: UserRole.encargado,
      avatar: 'LM',
      password: 'encargado2024',
      companyId: 'C002',
    ),
    AppUser(
      id: 'U006',
      name: 'C.P.C. Pedro Sanchez',
      email: 'pedro.sanchez@contadores.com',
      role: UserRole.encargado,
      avatar: 'PS',
      password: 'encargado2024',
      companyId: 'C003',
    ),
  ];

  List<Student> _seedStudents() => [
    Student(
      id: 'S001',
      name: 'Juan Perez Lopez',
      code: '2021001',
      email: 'juan.perez@student.edu.pe',
      phone: '987654321',
      program: programs[0],
      semester: 'VI',
    ),
    Student(
      id: 'S002',
      name: 'Maria Gonzalez Ruiz',
      code: '2021002',
      email: 'maria.gonzalez@student.edu.pe',
      phone: '987654322',
      program: programs[1],
      semester: 'IV',
    ),
    Student(
      id: 'S003',
      name: 'Carlos Infante Torres',
      code: '2021003',
      email: 'carlos.infante@student.edu.pe',
      phone: '987654323',
      program: programs[2],
      semester: 'VI',
    ),
    Student(
      id: 'S004',
      name: 'Ana Mogollon Silva',
      code: '2021004',
      email: 'ana.mogollon@student.edu.pe',
      phone: '987654324',
      program: programs[3],
      semester: 'III',
    ),
  ];

  List<Company> _seedCompanies() => [
    Company(
      id: 'C001',
      name: 'Tech Solutions SAC',
      ruc: '20567890123',
      address: 'Av. Principal 123, Zorritos',
      contact: 'Roberto Diaz',
      phone: '073-544001',
      email: 'contacto@techsolutions.com',
      latitude: -3.6817,
      longitude: -80.6760,
      totalVacancies: 4,
    ),
    Company(
      id: 'C002',
      name: 'Corporacion Empresarial del Norte',
      ruc: '20567890124',
      address: 'Jr. Comercio 456, Zorritos',
      contact: 'Laura Martinez',
      phone: '073-544002',
      email: 'rrhh@corpnorte.com',
      latitude: -3.6820,
      longitude: -80.6770,
      totalVacancies: 3,
    ),
    Company(
      id: 'C003',
      name: 'Contadores Asociados',
      ruc: '20567890125',
      address: 'Calle Grau 789, Zorritos',
      contact: 'Pedro Sanchez',
      phone: '073-544003',
      email: 'info@contadores.com',
      latitude: -3.6825,
      longitude: -80.6765,
      totalVacancies: 2,
    ),
  ];

  List<Practice> _seedPractices() => [
    Practice(
      id: 'P001',
      student: _students[0],
      company: _companies[0],
      practiceModule: 'I',
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 8, 30),
      requiredHours: 480,
      accumulatedHours: 320,
      status: PracticeStatus.active,
      learningObjective:
          'Desarrollar aplicaciones web y gestionar bases de datos en un entorno empresarial.',
      completedObjectives: const [
        'Desarrollar interfaces',
        'Control de versiones',
      ],
      pendingObjectives: const ['Documentación final'],
      monthlyReports: const [
        'Marzo: inducción y tareas básicas.',
        'Abril: desarrollo de modulos web.',
      ],
    ),
    Practice(
      id: 'P002',
      student: _students[1],
      company: _companies[1],
      practiceModule: 'II',
      startDate: DateTime(2026, 3, 15),
      endDate: DateTime(2026, 7, 15),
      requiredHours: 480,
      accumulatedHours: 180,
      status: PracticeStatus.active,
      learningObjective:
          'Fortalecer gestion administrativa, atención al cliente y manejo documental.',
      completedObjectives: const ['Atencion al cliente'],
      pendingObjectives: const ['Archivo documentario', 'Reporte final'],
      monthlyReports: const [
        'Marzo: adaptación al área.',
        'Abril: registro documentario.',
      ],
    ),
    Practice(
      id: 'P003',
      student: _students[2],
      company: _companies[2],
      practiceModule: 'III',
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2026, 5, 31),
      requiredHours: 480,
      accumulatedHours: 480,
      status: PracticeStatus.completed,
      learningObjective:
          'Aplicar procesos contables y elaborar reportes financieros.',
      completedObjectives: const ['Conciliación', 'Estados financieros'],
      pendingObjectives: const [],
      monthlyReports: const [
        'Febrero: registro contable.',
        'Marzo: conciliaciones bancarias.',
      ],
    ),
  ];

  List<Vacancy> _seedVacancies() => [
    Vacancy(
      id: 'V001',
      company: _companies[0],
      position: 'Desarrollador Junior',
      description: 'Apoyo en aplicaciones web y control de datos.',
      requiredHours: 240,
      schedule: 'Lunes a Viernes 8:00 AM - 5:00 PM',
      status: VacancyStatus.occupied,
      student: _students[0],
    ),
    Vacancy(
      id: 'V002',
      company: _companies[1],
      position: 'Asistente Administrativo',
      description: 'Gestión documental, atención y soporte operativo.',
      requiredHours: 220,
      schedule: 'Lunes a Viernes 9:00 AM - 3:00 PM',
      status: VacancyStatus.open,
    ),
    Vacancy(
      id: 'V003',
      company: _companies[2],
      position: 'Auxiliar Contable',
      description: 'Registro contable, conciliaciones y apoyo tributario.',
      requiredHours: 220,
      schedule: 'Lunes a Viernes 8:00 AM - 4:00 PM',
      status: VacancyStatus.closed,
    ),
  ];
}

class SessionController extends ChangeNotifier {
  SessionController._();
  static final SessionController instance = SessionController._();
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  void login(AppUser user) {
    _currentUser = user;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
