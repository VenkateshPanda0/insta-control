class FocusMode {
  const FocusMode({
    required this.id,
    required this.name,
    required this.summary,
    required this.minutes,
    this.restrictApps = false,
    this.builtIn = false,
  });
  final String id;
  final String name;
  final String summary;
  final int minutes;

  /// Restrict the chosen apps during the session, where the device allows.
  final bool restrictApps;
  final bool builtIn;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'minutes': minutes,
    'restrictApps': restrictApps,
  };

  static FocusMode? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'], minutes = json['minutes'];
    if (id is! String || name is! String || minutes is! int || minutes <= 0) {
      return null;
    }
    return FocusMode(
      id: id,
      name: name,
      summary: 'Custom mode',
      minutes: minutes,
      restrictApps: json['restrictApps'] == true,
    );
  }
}

const builtInFocusModes = <FocusMode>[
  FocusMode(
    id: 'study',
    name: 'Study',
    summary: 'A short, single-task block.',
    minutes: 25,
    restrictApps: true,
    builtIn: true,
  ),
  FocusMode(
    id: 'work',
    name: 'Work',
    summary: 'A longer block for getting things done.',
    minutes: 50,
    restrictApps: true,
    builtIn: true,
  ),
  FocusMode(
    id: 'deep',
    name: 'Deep Focus',
    summary: 'A long uninterrupted session.',
    minutes: 90,
    restrictApps: true,
    builtIn: true,
  ),
  FocusMode(
    id: 'social',
    name: 'Social',
    summary: 'Time-boxed catching up, nothing restricted.',
    minutes: 15,
    builtIn: true,
  ),
  FocusMode(
    id: 'sleep',
    name: 'Sleep',
    summary: 'Wind down for the night.',
    minutes: 480,
    restrictApps: true,
    builtIn: true,
  ),
];

class ActiveSession {
  const ActiveSession({
    required this.modeName,
    required this.startedAt,
    required this.endsAt,
    required this.restricting,
  });
  final String modeName;
  final DateTime startedAt;
  final DateTime endsAt;

  /// True when this session turned app restrictions on and must lift them.
  final bool restricting;

  Map<String, Object?> toJson() => {
    'modeName': modeName,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'endsAt': endsAt.millisecondsSinceEpoch,
    'restricting': restricting,
  };

  static ActiveSession? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['modeName'], s = json['startedAt'], e = json['endsAt'];
    if (name is! String || s is! int || e is! int || e <= s) return null;
    return ActiveSession(
      modeName: name,
      startedAt: DateTime.fromMillisecondsSinceEpoch(s),
      endsAt: DateTime.fromMillisecondsSinceEpoch(e),
      restricting: json['restricting'] == true,
    );
  }
}

class SessionRecord {
  const SessionRecord({
    required this.modeName,
    required this.startedAt,
    required this.plannedMinutes,
    required this.actualMinutes,
    required this.completed,
  });
  final String modeName;
  final DateTime startedAt;
  final int plannedMinutes;
  final int actualMinutes;
  final bool completed;

  Map<String, Object?> toJson() => {
    'modeName': modeName,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'plannedMinutes': plannedMinutes,
    'actualMinutes': actualMinutes,
    'completed': completed,
  };

  static SessionRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['modeName'], s = json['startedAt'];
    final p = json['plannedMinutes'], a = json['actualMinutes'];
    if (name is! String || s is! int || p is! int || a is! int) return null;
    return SessionRecord(
      modeName: name,
      startedAt: DateTime.fromMillisecondsSinceEpoch(s),
      plannedMinutes: p,
      actualMinutes: a,
      completed: json['completed'] == true,
    );
  }
}

class FocusState {
  const FocusState({
    this.customModes = const [],
    this.active,
    this.history = const [],
  });
  final List<FocusMode> customModes;
  final ActiveSession? active;

  /// Newest first.
  final List<SessionRecord> history;

  List<FocusMode> get modes => [...builtInFocusModes, ...customModes];

  Map<String, Object?> toJson() => {
    'customModes': [for (final m in customModes) m.toJson()],
    'active': active?.toJson(),
    'history': [for (final r in history) r.toJson()],
  };

  factory FocusState.fromJson(Object? json) {
    if (json is! Map) return const FocusState();
    List<T> list<T>(Object? raw, T? Function(Object?) parse) => [
      if (raw is List)
        for (final item in raw) ?parse(item),
    ];
    return FocusState(
      customModes: list(json['customModes'], FocusMode.fromJson),
      active: ActiveSession.fromJson(json['active']),
      history: list(json['history'], SessionRecord.fromJson),
    );
  }
}

/// Minutes of focus recorded on the calendar day of [day].
int focusMinutesOn(List<SessionRecord> history, DateTime day) => history
    .where(
      (r) =>
          r.startedAt.year == day.year &&
          r.startedAt.month == day.month &&
          r.startedAt.day == day.day,
    )
    .fold(0, (sum, r) => sum + r.actualMinutes);
