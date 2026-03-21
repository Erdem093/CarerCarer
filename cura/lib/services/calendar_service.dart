import 'package:device_calendar/device_calendar.dart';
import 'package:logger/logger.dart';

class CalendarEvent {
  final String title;
  final DateTime start;
  final DateTime? end;
  final String? location;
  final String? notes;
  final String? calendarId;

  const CalendarEvent({
    required this.title,
    required this.start,
    this.end,
    this.location,
    this.notes,
    this.calendarId,
  });
}

class CalendarService {
  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  final Logger _log = Logger();
  List<Calendar>? _calendars;

  /// Requests calendar read/write permission. Returns true if granted.
  Future<bool> requestPermission() async {
    final result = await _plugin.requestPermissions();
    return result.isSuccess && (result.data ?? false);
  }

  /// Returns true if permission is already granted.
  Future<bool> hasPermission() async {
    final result = await _plugin.hasPermissions();
    return result.isSuccess && (result.data ?? false);
  }

  /// Fetches upcoming events from all device calendars within [days] days.
  Future<List<CalendarEvent>> getUpcomingEvents({int days = 7}) async {
    try {
      if (!await hasPermission()) return [];

      _calendars ??= await _fetchCalendars();
      if (_calendars == null || _calendars!.isEmpty) return [];

      final now = DateTime.now();
      final end = now.add(Duration(days: days));
      final events = <CalendarEvent>[];

      for (final calendar in _calendars!) {
        final result = await _plugin.retrieveEvents(
          calendar.id!,
          RetrieveEventsParams(startDate: now, endDate: end),
        );
        if (result.isSuccess && result.data != null) {
          for (final e in result.data!) {
            if (e.title != null && e.start != null) {
              events.add(CalendarEvent(
                title: e.title!,
                start: e.start!,
                end: e.end,
                location: e.location,
                notes: e.description,
                calendarId: calendar.id,
              ));
            }
          }
        }
      }

      events.sort((a, b) => a.start.compareTo(b.start));
      return events.take(20).toList(); // cap for LLM context size
    } catch (e) {
      _log.e('Calendar fetch error: $e');
      return [];
    }
  }

  /// Creates a new event in the default calendar. Returns the event ID or null.
  Future<String?> createEvent(CalendarEvent event) async {
    try {
      if (!await hasPermission()) return null;
      _calendars ??= await _fetchCalendars();

      final defaultCalendar = _calendars?.firstWhere(
        (c) => c.isDefault ?? false,
        orElse: () => _calendars!.first,
      );

      if (defaultCalendar == null) return null;

      final newEvent = Event(
        defaultCalendar.id!,
        title: event.title,
        start: TZDateTime.from(event.start, local),
        end: TZDateTime.from(
          event.end ?? event.start.add(const Duration(hours: 1)),
          local,
        ),
        location: event.location,
        description: event.notes,
      );

      final result = await _plugin.createOrUpdateEvent(newEvent);
      if (result?.isSuccess ?? false) {
        return result!.data;
      }
      return null;
    } catch (e) {
      _log.e('Calendar create event error: $e');
      return null;
    }
  }

  /// Formats events as natural language for LLM context injection.
  String formatEventsForLLM(List<CalendarEvent> events) {
    if (events.isEmpty) return 'No upcoming appointments in the next 7 days.';

    final lines = events.map((e) {
      final dateStr = _formatDate(e.start);
      final timeStr = e.start.hour != 0 || e.start.minute != 0
          ? ' at ${_formatTime(e.start)}'
          : '';
      final locationStr = e.location != null ? ' (${e.location})' : '';
      return '- $dateStr$timeStr: ${e.title}$locationStr';
    });

    return lines.join('\n');
  }

  Future<List<Calendar>> _fetchCalendars() async {
    final result = await _plugin.retrieveCalendars();
    return result.data?.where((c) => !(c.isReadOnly ?? true)).toList() ?? [];
  }

  String _formatDate(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
