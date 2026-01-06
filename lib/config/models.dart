/// Activity Model
import 'package:intl/intl.dart';
class ActivityRecord {
  final String date;
  final String checkIn;
  final String checkOut;
  // final String? accuracy;
  // final String? photo;
  final String status;
  final String caption;

  ActivityRecord({
    required this.date,
    required this.checkIn,
    required this.checkOut,
    // this.accuracy,
    // this.photo,
    required this.status,
    required this.caption,
  });

  /// Factory constructor to create ActivityRecord from JSON
  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    String formattedDate = json['timestamp']?.toString() ?? '';
    try {
      if (formattedDate.isNotEmpty) {
        // Expected api format: 2025-12-18 17-02-19
        final inputFormat = DateFormat('yyyy-MM-dd HH-mm-ss');
        final dateTime = inputFormat.parse(formattedDate);
        formattedDate = DateFormat('dd MMM yyyy HH:mm a').format(dateTime);
      }
    } catch (e) {
      // If parsing fails (e.g. different format), keep original string
      // print('Date parsing error: $e');
    }

    return ActivityRecord(
      date: formattedDate,
      checkIn: json['latitude']?.toString() ?? json['check_in']?.toString() ?? '-',
      checkOut: json['longitude']?.toString() ?? json['check_out']?.toString() ?? '-',
      status: json['status']?.toString() ?? ' ',
      caption: json['caption']?.toString() ?? '-',
    );
  }

  /// Get status color based on status string
  String getStatusColor() {
    switch (status.toLowerCase()) {
      case 'on time':
      case 'ontime':
        return '#4CAF50'; // Green
      case 'late':
        return '#4CAF50'; // Orange
        // return '#FFA726'; // Orange
      case 'absent':
        return '#4CAF50'; // Red
        // return '#EF5350'; // Red
      default:
        // return '#9E9E9E'; // Grey
        return '#4CAF50'; // Grey
    }
  }
}
