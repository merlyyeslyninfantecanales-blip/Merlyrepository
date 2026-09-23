import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_data_service.dart';
import 'supabase_config.dart';

class AppUpdateInfo {
  final String versionName;
  final int versionCode;
  final String? apkUrl;
  final String notes;
  final DateTime createdAt;

  const AppUpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.notes,
    required this.createdAt,
  });
}

class SupabaseDatabaseService {
  SupabaseDatabaseService._();

  static final instance = SupabaseDatabaseService._();

  bool get isReady => SupabaseConfig.isConfigured;

  SupabaseClient get _client => Supabase.instance.client;

  AppUser _profileFromRow(Map<String, dynamic> row) {
    final name = '${row['full_name'] ?? ''}'.trim();
    final roleName = '${row['role'] ?? ''}'.trim();
    final role = userRoleFromRoute(roleName) ?? UserRole.estudiante;
    return AppUser(
      id: '${row['id']}',
      name: name,
      email: '${row['email'] ?? ''}',
      role: role,
      avatar: '${row['avatar'] ?? _initials(name)}',
      password: '',
      companyId: row['company_id']?.toString(),
      studentId: row['student_id']?.toString(),
      authUserId: row['auth_user_id']?.toString(),
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'US';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<bool> checkConnection() async {
    if (!isReady) return false;
    await _client.from('profiles').select('id').limit(1);
    return true;
  }

  Future<List<AppUser>> getUsersByRole(UserRole role) async {
    if (!isReady) return const [];
    final rows = await _client
        .from('profiles')
        .select()
        .eq('role', role.name)
        .order('full_name', ascending: true);
    return List<Map<String, dynamic>>.from(rows).map(_profileFromRow).toList();
  }

  Future<List<AppUser>> loadUsers() async {
    if (!isReady) return const [];
    final rows = await _client
        .from('profiles')
        .select()
        .order('full_name', ascending: true);
    return List<Map<String, dynamic>>.from(rows).map(_profileFromRow).toList();
  }

  Future<AppUser> saveProfile(AppUser user) async {
    final payload = {
      'role': user.role.name,
      'full_name': user.name,
      'email': user.email,
      'avatar': user.avatar.isEmpty ? _initials(user.name) : user.avatar,
      'company_id': _uuidOrNull(user.companyId),
      'student_id': _uuidOrNull(user.studentId),
    };

    final row = _isUuid(user.id)
        ? await _client
              .from('profiles')
              .update(payload)
              .eq('id', user.id)
              .select()
              .single()
        : await _client
              .from('profiles')
              .upsert(payload, onConflict: 'email')
              .select()
              .single();
    return _profileFromRow(Map<String, dynamic>.from(row));
  }

  Future<void> deleteProfile(AppUser user) async {
    if (_isUuid(user.id)) {
      await _client.from('profiles').delete().eq('id', user.id);
    } else {
      await _client.from('profiles').delete().eq('email', user.email);
    }
  }

  Future<AppUser> adminCreateUser(AppUser user) async {
    final password = user.password.trim().isEmpty
        ? 'PracticApp2026*'
        : user.password;
    final response = await _client.functions.invoke(
      'admin-users',
      body: {
        'action': 'create',
        'name': user.name,
        'email': user.email,
        'password': password,
        'role': user.role.name,
        'companyId': _uuidOrNull(user.companyId),
        'studentId': _uuidOrNull(user.studentId),
        'avatar': user.avatar.isEmpty ? _initials(user.name) : user.avatar,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['error'] != null) throw Exception('${data['error']}');
    return _profileFromRow(Map<String, dynamic>.from(data['profile'] as Map));
  }

  Future<AppUser> adminUpdateUser(AppUser user) async {
    if (!_isUuid(user.id)) {
      return adminCreateUser(user);
    }
    final response = await _client.functions.invoke(
      'admin-users',
      body: {
        'action': 'update',
        'profileId': user.id,
        'authUserId': user.authUserId,
        'name': user.name,
        'email': user.email,
        'password': user.password,
        'role': user.role.name,
        'companyId': _uuidOrNull(user.companyId),
        'studentId': _uuidOrNull(user.studentId),
        'avatar': user.avatar.isEmpty ? _initials(user.name) : user.avatar,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['error'] != null) throw Exception('${data['error']}');
    return _profileFromRow(Map<String, dynamic>.from(data['profile'] as Map));
  }

  Future<void> adminDeleteUser(AppUser user) async {
    final response = await _client.functions.invoke(
      'admin-users',
      body: {
        'action': 'delete',
        'profileId': user.id,
        'authUserId': user.authUserId,
        'email': user.email,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['error'] != null) throw Exception('${data['error']}');
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final authUser = response.user;
    if (authUser == null) {
      throw const AuthException('No se pudo iniciar sesión.');
    }

    final rowsByAuthId = await _client
        .from('profiles')
        .select()
        .eq('auth_user_id', authUser.id)
        .limit(1);
    var list = List<Map<String, dynamic>>.from(rowsByAuthId);
    if (list.isEmpty) {
      final rowsByEmail = await _client
          .from('profiles')
          .select()
          .eq('email', email)
          .limit(1);
      list = List<Map<String, dynamic>>.from(rowsByEmail);
    }

    if (list.isEmpty) {
      await _client.auth.signOut();
      throw const AuthException('No existe un perfil para este usuario.');
    }

    final profile = _profileFromRow(list.first);
    if (profile.role != expectedRole) {
      await _client.auth.signOut();
      throw AuthException(
        'Este usuario no pertenece al rol ${expectedRole.label}.',
      );
    }
    return profile;
  }

  Future<void> signOut() async {
    if (!isReady) return;
    await _client.auth.signOut();
  }

  Future<AppUser?> restoreCurrentProfile() async {
    if (!isReady) return null;
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    final rowsByAuthId = await _client
        .from('profiles')
        .select()
        .eq('auth_user_id', authUser.id)
        .limit(1);
    var list = List<Map<String, dynamic>>.from(rowsByAuthId);
    if (list.isEmpty && authUser.email != null) {
      final rowsByEmail = await _client
          .from('profiles')
          .select()
          .eq('email', authUser.email!)
          .limit(1);
      list = List<Map<String, dynamic>>.from(rowsByEmail);
    }
    if (list.isEmpty) return null;
    return _profileFromRow(list.first);
  }

  Future<AppUpdateInfo?> loadLatestAppUpdate() async {
    if (!isReady) return null;
    final rows = await _client
        .from('app_updates')
        .select()
        .eq('active', true)
        .order('version_code', ascending: false)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(rows);
    if (list.isEmpty) return null;
    final row = list.first;
    return AppUpdateInfo(
      versionName: '${row['version_name'] ?? ''}',
      versionCode: (row['version_code'] as num?)?.toInt() ?? 0,
      apkUrl: row['apk_url']?.toString(),
      notes: '${row['notes'] ?? ''}',
      createdAt: DateTime.tryParse('${row['created_at']}') ?? DateTime.now(),
    );
  }

  Future<List<Map<String, dynamic>>> getCompanies() async {
    final rows = await _client
        .from('companies')
        .select()
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> getStudents() async {
    final rows = await _client
        .from('students')
        .select()
        .order('full_name', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Student>> loadStudents() async {
    final rows = await getStudents();
    return rows.map(_studentFromRow).toList();
  }

  Future<List<Company>> loadCompanies() async {
    final rows = await getCompanies();
    return rows.map(_companyFromRow).toList();
  }

  Student _studentFromRow(Map<String, dynamic> row) {
    return Student(
      id: '${row['id']}',
      name: '${row['full_name'] ?? ''}',
      code: '${row['code'] ?? ''}',
      email: '${row['email'] ?? ''}',
      phone: '${row['phone'] ?? ''}',
      program: '${row['program'] ?? ''}',
      semester: '${row['semester'] ?? ''}',
    );
  }

  Company _companyFromRow(Map<String, dynamic> row) {
    return Company(
      id: '${row['id']}',
      name: '${row['name'] ?? ''}',
      ruc: '${row['ruc'] ?? ''}',
      address: '${row['address'] ?? ''}',
      contact: '${row['contact_name'] ?? ''}',
      phone: '${row['phone'] ?? ''}',
      email: '${row['email'] ?? ''}',
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
      totalVacancies: (row['total_vacancies'] as num?)?.toInt() ?? 0,
    );
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  String? _uuidOrNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _isUuid(value.trim()) ? value.trim() : null;
  }

  Future<Student> saveStudent(Student student) async {
    final payload = {
      'full_name': student.name,
      'code': student.code,
      'email': student.email.isEmpty
          ? '${student.code}@student.practicapp.pe'
          : student.email,
      'phone': student.phone,
      'program': student.program,
      'semester': student.semester,
    };

    if (_isUuid(student.id)) {
      final row = await _client
          .from('students')
          .update(payload)
          .eq('id', student.id)
          .select()
          .single();
      return _studentFromRow(Map<String, dynamic>.from(row));
    }

    final row = await _client
        .from('students')
        .upsert(payload, onConflict: 'code')
        .select()
        .single();
    return _studentFromRow(Map<String, dynamic>.from(row));
  }

  Future<void> deleteStudent(Student student) async {
    if (_isUuid(student.id)) {
      await _client.from('students').delete().eq('id', student.id);
    } else {
      await _client.from('students').delete().eq('code', student.code);
    }
  }

  Future<Company> saveCompany(Company company) async {
    final payload = {
      'name': company.name,
      'ruc': company.ruc,
      'phone': company.phone,
      'address': company.address,
      'contact_name': company.contact,
      'email': company.email,
      'latitude': company.latitude,
      'longitude': company.longitude,
      'total_vacancies': company.totalVacancies,
    };

    if (_isUuid(company.id)) {
      final row = await _client
          .from('companies')
          .update(payload)
          .eq('id', company.id)
          .select()
          .single();
      return _companyFromRow(Map<String, dynamic>.from(row));
    }

    final row = await _client
        .from('companies')
        .upsert(payload, onConflict: 'ruc')
        .select()
        .single();
    return _companyFromRow(Map<String, dynamic>.from(row));
  }

  Future<void> deleteCompany(Company company) async {
    if (_isUuid(company.id)) {
      await _client.from('companies').delete().eq('id', company.id);
    } else {
      await _client.from('companies').delete().eq('ruc', company.ruc);
    }
  }

  Future<Practice> savePractice(Practice practice) async {
    final student = await saveStudent(practice.student);
    final company = await saveCompany(practice.company);
    practice.student.id = student.id;
    practice.student.email = student.email;
    practice.student.semester = student.semester;
    practice.company.id = company.id;

    final payload = {
      'student_id': student.id,
      'company_id': company.id,
      'practice_module': practice.practiceModule,
      'shift': practice.shift,
      'start_date': _dateOnly(practice.startDate),
      'end_date': practice.status == PracticeStatus.completed
          ? _dateOnly(practice.endDate)
          : null,
      'required_hours': practice.requiredHours,
      'accumulated_hours': practice.accumulatedHours,
      'status': practice.status.name,
      'learning_objective': practice.learningObjective,
      'completed_objectives': practice.completedObjectives,
      'pending_objectives': practice.pendingObjectives,
      'monthly_reports': practice.monthlyReports,
      'certificate_issued': practice.certificateIssued,
    };

    final Map<String, dynamic> row;
    if (_isUuid(practice.id)) {
      row = Map<String, dynamic>.from(
        await _client
            .from('practices')
            .update(payload)
            .eq('id', practice.id)
            .select()
            .single(),
      );
    } else {
      row = Map<String, dynamic>.from(
        await _client.from('practices').insert(payload).select().single(),
      );
    }
    practice.id = '${row['id']}';
    return practice;
  }

  Future<void> deletePractice(Practice practice) async {
    if (!_isUuid(practice.id)) return;
    await _client.from('practices').delete().eq('id', practice.id);
  }

  String _dateOnly(DateTime value) => value.toIso8601String().split('T').first;

  Future<List<Map<String, dynamic>>> getPractices() async {
    final rows = await _client
        .from('practices')
        .select('*, students(*), companies(*)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Practice>> loadPractices() async {
    final rows = await getPractices();
    return rows.map((row) {
      final studentRow = Map<String, dynamic>.from(row['students'] as Map);
      final companyRow = Map<String, dynamic>.from(row['companies'] as Map);
      final statusName = '${row['status'] ?? 'active'}';
      final status = PracticeStatus.values.firstWhere(
        (item) => item.name == statusName,
        orElse: () => PracticeStatus.active,
      );
      return Practice(
        id: '${row['id']}',
        student: _studentFromRow(studentRow),
        company: _companyFromRow(companyRow),
        practiceModule: '${row['practice_module'] ?? 'I'}',
        shift: '${row['shift'] ?? 'Día completo'}',
        startDate: DateTime.tryParse('${row['start_date']}') ?? DateTime.now(),
        endDate: DateTime.tryParse('${row['end_date']}') ?? DateTime.now(),
        requiredHours: (row['required_hours'] as num?)?.toInt() ?? 0,
        accumulatedHours: (row['accumulated_hours'] as num?)?.toInt() ?? 0,
        status: status,
        learningObjective: '${row['learning_objective'] ?? ''}',
        completedObjectives: List<String>.from(
          row['completed_objectives'] ?? const [],
        ),
        pendingObjectives: List<String>.from(
          row['pending_objectives'] ?? const [],
        ),
        monthlyReports: List<String>.from(row['monthly_reports'] ?? const []),
        certificateIssued: row['certificate_issued'] == true,
      );
    }).toList();
  }

  Attendance _attendanceFromRow(Map<String, dynamic> row) {
    final statusName = '${row['status'] ?? 'present'}';
    final status = AttendanceStatus.values.firstWhere(
      (item) => item.name == statusName,
      orElse: () => AttendanceStatus.present,
    );
    return Attendance(
      id: '${row['id']}',
      practiceId: '${row['practice_id']}',
      date: DateTime.tryParse('${row['attendance_date']}') ?? DateTime.now(),
      status: status,
      hours: (row['hours'] as num?)?.toDouble() ?? 0,
      notes: '${row['notes'] ?? ''}',
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
    );
  }

  Evaluation _evaluationFromRow(Map<String, dynamic> row) {
    return Evaluation(
      id: '${row['id']}',
      practiceId: '${row['practice_id']}',
      title: '${row['title'] ?? ''}',
      score: (row['score'] as num?)?.toInt() ?? 0,
      comment: '${row['comment'] ?? ''}',
      performance: '${row['performance'] ?? ''}',
      pdfName: row['pdf_path']?.toString(),
    );
  }

  TrackingRecord _trackingFromRow(Map<String, dynamic> row) {
    return TrackingRecord(
      id: '${row['id']}',
      practiceId: '${row['practice_id']}',
      title: '${row['title'] ?? ''}',
      progress: (row['progress'] as num?)?.toInt() ?? 0,
      completedObjectives: '${row['completed_objectives'] ?? ''}',
      pendingObjectives: '${row['pending_objectives'] ?? ''}',
      monthlyReport: '${row['monthly_report'] ?? ''}',
      pdfName: row['pdf_path']?.toString(),
    );
  }

  Vacancy _vacancyFromRow(Map<String, dynamic> row) {
    final companyRow = Map<String, dynamic>.from(row['companies'] as Map);
    final studentRaw = row['students'];
    final statusName = '${row['status'] ?? 'open'}';
    final status = VacancyStatus.values.firstWhere(
      (item) => item.name == statusName,
      orElse: () => VacancyStatus.open,
    );
    return Vacancy(
      id: '${row['id']}',
      company: _companyFromRow(companyRow),
      position: '${row['position'] ?? ''}',
      description: '${row['description'] ?? ''}',
      requirements: '${row['requirements'] ?? ''}',
      requiredHours: (row['required_hours'] as num?)?.toInt() ?? 160,
      schedule: '${row['schedule'] ?? ''}',
      shift: '${row['shift'] ?? 'Día completo'}',
      status: status,
      student: studentRaw == null
          ? null
          : _studentFromRow(Map<String, dynamic>.from(studentRaw as Map)),
    );
  }

  Future<Map<String, List<Attendance>>> loadAllAttendanceRecords() async {
    final rows = await _client
        .from('attendance_records')
        .select()
        .order('attendance_date', ascending: false);
    final map = <String, List<Attendance>>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final attendance = _attendanceFromRow(row);
      map.putIfAbsent(attendance.practiceId, () => []).add(attendance);
    }
    return map;
  }

  Future<Map<String, List<Evaluation>>> loadAllEvaluations() async {
    final rows = await _client
        .from('evaluations')
        .select()
        .order('created_at', ascending: false);
    final map = <String, List<Evaluation>>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final evaluation = _evaluationFromRow(row);
      map.putIfAbsent(evaluation.practiceId, () => []).add(evaluation);
    }
    return map;
  }

  Future<Map<String, List<TrackingRecord>>> loadAllTrackingRecords() async {
    final rows = await _client
        .from('tracking_records')
        .select()
        .order('created_at', ascending: false);
    final map = <String, List<TrackingRecord>>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final record = _trackingFromRow(row);
      map.putIfAbsent(record.practiceId, () => []).add(record);
    }
    return map;
  }

  Future<List<Vacancy>> loadVacancies() async {
    final rows = await _client
        .from('vacancies')
        .select('*, companies(*), students(*)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows).map(_vacancyFromRow).toList();
  }

  Future<Attendance> saveAttendance(Attendance attendance) async {
    final payload = {
      'practice_id': attendance.practiceId,
      'attendance_date': _dateOnly(attendance.date),
      'status': attendance.status.name,
      'hours': attendance.hours,
      'notes': attendance.notes,
      'latitude': attendance.latitude,
      'longitude': attendance.longitude,
    };
    final row = _isUuid(attendance.id)
        ? await _client
              .from('attendance_records')
              .update(payload)
              .eq('id', attendance.id)
              .select()
              .single()
        : await _client
              .from('attendance_records')
              .insert(payload)
              .select()
              .single();
    attendance.id = '${row['id']}';
    return attendance;
  }

  Future<Evaluation> saveEvaluation(Evaluation evaluation) async {
    final payload = {
      'practice_id': evaluation.practiceId,
      'title': evaluation.title,
      'score': evaluation.score,
      'comment': evaluation.comment,
      'performance': evaluation.performance,
      'pdf_path': evaluation.pdfName,
    };
    final row = _isUuid(evaluation.id)
        ? await _client
              .from('evaluations')
              .update(payload)
              .eq('id', evaluation.id)
              .select()
              .single()
        : await _client.from('evaluations').insert(payload).select().single();
    evaluation.id = '${row['id']}';
    return evaluation;
  }

  Future<TrackingRecord> saveTrackingRecord(TrackingRecord record) async {
    final payload = {
      'practice_id': record.practiceId,
      'title': record.title,
      'progress': record.progress,
      'completed_objectives': record.completedObjectives,
      'pending_objectives': record.pendingObjectives,
      'monthly_report': record.monthlyReport,
      'pdf_path': record.pdfName,
    };
    final row = _isUuid(record.id)
        ? await _client
              .from('tracking_records')
              .update(payload)
              .eq('id', record.id)
              .select()
              .single()
        : await _client
              .from('tracking_records')
              .insert(payload)
              .select()
              .single();
    record.id = '${row['id']}';
    return record;
  }

  Future<Vacancy> saveVacancy(Vacancy vacancy) async {
    final company = await saveCompany(vacancy.company);
    vacancy.company.id = company.id;
    final payload = {
      'company_id': company.id,
      'position': vacancy.position,
      'description': vacancy.description,
      'requirements': vacancy.requirements,
      'required_hours': vacancy.requiredHours,
      'schedule': vacancy.schedule,
      'shift': vacancy.shift,
      'status': vacancy.status.name,
      'student_id': vacancy.student?.id,
    };
    final row = _isUuid(vacancy.id)
        ? await _client
              .from('vacancies')
              .update(payload)
              .eq('id', vacancy.id)
              .select()
              .single()
        : await _client.from('vacancies').insert(payload).select().single();
    vacancy.id = '${row['id']}';
    return vacancy;
  }

  Future<void> deleteVacancy(Vacancy vacancy) async {
    if (!_isUuid(vacancy.id)) return;
    await _client.from('vacancies').delete().eq('id', vacancy.id);
  }

  Future<void> saveCertificate(Practice practice, {String? pdfPath}) async {
    await savePractice(practice);
    await _client.from('certificates').upsert({
      'practice_id': practice.id,
      'student_id': practice.student.id,
      'pdf_path': pdfPath,
    }, onConflict: 'practice_id');
  }

  Future<List<Map<String, dynamic>>> getAttendanceRecords(
    String practiceId,
  ) async {
    final rows = await _client
        .from('attendance_records')
        .select()
        .eq('practice_id', practiceId)
        .order('attendance_date', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> getEvaluations(String practiceId) async {
    final rows = await _client
        .from('evaluations')
        .select()
        .eq('practice_id', practiceId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> getTrackingRecords(
    String practiceId,
  ) async {
    final rows = await _client
        .from('tracking_records')
        .select()
        .eq('practice_id', practiceId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<String> uploadDocument({
    required String path,
    required Uint8List bytes,
    String contentType = 'application/pdf',
  }) async {
    await _client.storage
        .from('practicapp-documents')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  }
}
