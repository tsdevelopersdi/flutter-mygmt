import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:excel/excel.dart';
import 'package:archive/archive_io.dart';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Data model for each inspection row.
class InspectionRow {
  final int number;
  final String inspectionRef;
  final String thing; // hardcoded label
  String condition; // editable: "good" | "bad"
  String action; // editable: "none" | "repair" | "replace" | "monitor"
  DateTime? actionDate; // editable
  XFile? photo; // editable
  String notes; // ✅ NEW FIELD

  InspectionRow({
    required this.number,
    required this.inspectionRef,
    required this.thing,
    this.condition = 'good',
    this.action = 'none',
    this.actionDate,
    this.photo,
    this.notes = '', // default empty
  });

  Map<String, dynamic> toJson() => {
    'number': number,
    'inspection_ref': inspectionRef,
    'inspection_thing': thing,
    'condition': condition,
    'action': action,
    'action_date': actionDate?.toIso8601String(),
    'photo_path': photo?.path,
    'notes': notes, // ✅ include in JSON
  };

  InspectionRow copy() => InspectionRow(
    number: number,
    inspectionRef: inspectionRef,
    thing: thing,
    condition: condition,
    action: action,
    actionDate: actionDate,
    photo: photo,
    notes: notes, // ✅ copy notes
  );
}

/// A ready-to-use page with AppBar and actions.
class GraderFormEditPage extends StatelessWidget {
  final List<InspectionRow>? initialRows;
  final void Function(List<InspectionRow> rows)? onSave;
  final Map formJson; // will hold the full form + inspection_rows
  final dynamic hiveKey; // new 👈

  const GraderFormEditPage({
    super.key,
    this.initialRows,
    this.onSave,
    required this.formJson,
    this.hiveKey,
  });

  @override
  Widget build(BuildContext context) {
    // Extract top form and inspection_rows from formJson
    final topForm = formJson['form'] as Map?;
    final inspectionRowsJson = formJson['inspection_rows'] as List?;

    // Convert inspectionRowsJson to List<InspectionRow>
    List<InspectionRow>? inspectionRows;
    if (inspectionRowsJson != null) {
      inspectionRows = inspectionRowsJson.map((row) {
        XFile? photoFile;
        if (row['photo_path'] != null &&
            row['photo_path'].toString().isNotEmpty) {
          photoFile = XFile(row['photo_path']);
        }
        return InspectionRow(
          number: row['number'],
          inspectionRef: row['inspection_ref'],
          thing: row['inspection_thing'],
          condition: row['condition'],
          notes: row['notes'],
          action: row['action'],
          actionDate: row['action_date'] != null
              ? DateTime.tryParse(row['action_date'])
              : null,
          photo: photoFile,
        );
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grader Inspection Edit Page'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 169, 255, 129),
                Color.fromARGB(255, 200, 229, 255),
              ], // yellow → orange
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: WorkingDocForm(
          initialRows: inspectionRows,
          onSave: onSave,
          topForm: topForm,
        ),
      ),
    );
  }
}

/// The embeddable form widget (no Scaffold).
class WorkingDocForm extends StatefulWidget {
  final List<InspectionRow>? initialRows;
  final void Function(List<InspectionRow> rows)? onSave;
  final Map? topForm;

  /// If true, shows Save and Reset buttons at the bottom.
  final bool showActions;

  const WorkingDocForm({
    super.key,
    this.initialRows,
    this.onSave,
    this.topForm,
    this.showActions = true,
  });

  @override
  State<WorkingDocForm> createState() => _WorkingDocFormState();
}

class _WorkingDocFormState extends State<WorkingDocForm> {
  final picker = ImagePicker();
  bool _isUploading = false;

  // controllers for top form inputs
  final TextEditingController _vehicleNoController = TextEditingController();
  final TextEditingController _hmKmController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _siteProjectController = TextEditingController();

  @override
  void dispose() {
    _vehicleNoController.dispose();
    _hmKmController.dispose();
    _lokasiController.dispose();
    _siteProjectController.dispose();
    super.dispose(); // <-- always call super.dispose()
  }

  String? _selectedOption; // inspektor
  String? _selectedOption2; // unit
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  XFile? _selectedPhoto;

  late final List<InspectionRow> rows;
  final conditions = const ['good', 'bad'];
  final actions = const ['none', 'repair', 'replace', 'monitor'];

  @override
  void initState() {
    super.initState();
    // Prefill top form fields if widget.topForm is provided
    if (widget.topForm != null) {
      _vehicleNoController.text =
          widget.topForm!['nomor_kendaraan']?.toString() ?? '';
      _hmKmController.text = widget.topForm!['hm_km']?.toString() ?? '';
      _lokasiController.text =
          widget.topForm!['lokasi_inspeksi']?.toString() ?? '';
      _siteProjectController.text =
          widget.topForm!['site_project']?.toString() ?? '';
      _selectedOption = widget.topForm!['inspektor']?.toString();
      _selectedOption2 = widget.topForm!['unit']?.toString();
      _selectedDate = widget.topForm!['tanggal'] != null
          ? DateTime.tryParse(widget.topForm!['tanggal'])
          : null;

      if (widget.topForm!['jam_inspeksi'] != null) {
        final timeStr = widget.topForm!['jam_inspeksi'].toString();
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            _selectedTime = TimeOfDay(hour: hour, minute: minute);
          }
        }
      }

      // ✅ Handle foto_extra (pre-fill extra photo)
      if (widget.topForm!['foto_extra'] != null &&
          widget.topForm!['foto_extra'].toString().isNotEmpty) {
        _selectedPhoto = XFile(widget.topForm!['foto_extra']);
      }
    }

    rows = (widget.initialRows ?? _defaultRows()).map((e) => e.copy()).toList();
  }

  List<InspectionRow> _defaultRows() => [
    InspectionRow(
      number: 1,
      inspectionRef: 'Vessel plate',
      thing: 'Periksa plat bengkok, retak dan lubang',
      condition: 'good',
      notes: 'No issues found',
      action: 'none',
      actionDate: null,
    ),
  ];

  String _fmtDate(DateTime? d) {
    if (d == null) return 'none';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
  }

  String _fmtTime(TimeOfDay? t) {
    if (t == null) return 'none';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<String?> _getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  @override
  Widget build(BuildContext context) {
    Widget _buildTopForm() {
      InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      );
      Widget _labeledField(String label, Widget child) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10)),
                const SizedBox(height: 1),
                SizedBox(height: 32, child: child),
              ],
            ),
          ),
        );
      }

      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 243, 244, 214),
              Color.fromARGB(255, 248, 198, 219),
            ], // yellow → orange
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(5),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _labeledField(
                  "Catatan Kendaraan",
                  TextField(
                    controller: _vehicleNoController,
                    style: const TextStyle(fontSize: 11),
                    decoration: _decoration("Enter..."),
                    readOnly: true,
                  ),
                ),
                _labeledField(
                  "HM/KM",
                  TextField(
                    controller: _hmKmController,
                    style: const TextStyle(fontSize: 11),
                    decoration: _decoration("Enter..."),
                    readOnly: true,
                  ),
                ),
                _labeledField(
                  "Lokasi Inspeksi",
                  TextField(
                    controller: _lokasiController,
                    style: const TextStyle(fontSize: 11),
                    decoration: _decoration("Enter..."),
                    readOnly: true,
                  ),
                ),
                _labeledField(
                  "Inspektor",
                  DropdownButtonFormField<String>(
                    value: _selectedOption,
                    isDense: true,
                    style: const TextStyle(fontSize: 11, color: Colors.black),
                    decoration: _decoration("Select..."),
                    items: ['Option A', 'Option B', 'Option C']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: null,
                  ),
                ),
                // Use the same unit list as in grader_form_page.dart
                _labeledField(
                  "Pilih Unit",
                  DropdownButtonFormField<String>(
                    value: _selectedOption2,
                    isDense: true,
                    style: const TextStyle(fontSize: 11, color: Colors.black),
                    decoration: _decoration("Select..."),
                    items:
                        [
                              'GC-120-01',
                              'GK-705-01',
                              'GN-265-01',
                              'GSE-919-01',
                              'GSE-921-01',
                              'GSE-922-01',
                            ]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: null,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _labeledField(
                  "Site Project",
                  TextField(
                    controller: _siteProjectController,
                    style: const TextStyle(fontSize: 11),
                    decoration: _decoration("Enter..."),
                    readOnly: true,
                  ),
                ),
                _labeledField(
                  "Tanggal",
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _fmtDate(_selectedDate),
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_month, size: 16),
                        onPressed: null,
                      ),
                    ],
                  ),
                ),
                _labeledField(
                  "Jam Inspeksi",
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _fmtTime(_selectedTime),
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.watch_later, size: 16),
                        onPressed: null,
                      ),
                    ],
                  ),
                ),
                _labeledField(
                  "Foto",
                  Row(
                    children: [
                      if (_selectedPhoto != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: kIsWeb
                                ? Image.network(
                                    _selectedPhoto!.path,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(_selectedPhoto!.path),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.photo_library, size: 16),
                        onPressed: null,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      );
    }

    DataRow _buildRow(InspectionRow r) {
      // final i = rows.indexOf(r); // Removed unused variable
      return DataRow(
        cells: [
          DataCell(Text(r.number.toString())),
          DataCell(Text(r.inspectionRef)),
          DataCell(Text(r.thing)),
          DataCell(
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: r.condition,
                items: conditions
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: null,
              ),
            ),
          ),
          DataCell(
            SizedBox(
              width: 120, // ✅ limit width so it doesn’t expand too much
              child: TextField(
                controller: TextEditingController(text: r.notes)
                  ..selection = TextSelection.collapsed(offset: r.notes.length),
                onChanged: null,
                readOnly: true,
                style: const TextStyle(fontSize: 11),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 6,
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          DataCell(
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: r.action,
                items: actions
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: null,
              ),
            ),
          ),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_fmtDate(r.actionDate)),
                const SizedBox(width: 8),
                FilledButton.tonal(onPressed: null, child: const Text('Pick')),
                if (r.actionDate != null)
                  IconButton(
                    tooltip: 'Clear date',
                    onPressed: null,
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
          ),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (r.photo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: kIsWeb
                          ? Image.network(r.photo!.path, fit: BoxFit.cover)
                          : Image.file(File(r.photo!.path), fit: BoxFit.cover),
                    ),
                  )
                else
                  const Text('No photo'),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: null,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose'),
                ),
                if (r.photo != null)
                  IconButton(
                    tooltip: 'Remove photo',
                    onPressed: null,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    List<DataRow> _buildTableRows() {
      final List<DataRow> tableRows = [];

      void addDivider(String title) {
        tableRows.add(
          DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 40, // same fixed width
                ),
              ),
              DataCell(
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    // decoration: TextDecoration.underline,
                  ),
                ),
              ),

              DataCell(SizedBox()),
              DataCell(SizedBox()),
              DataCell(SizedBox()),
              DataCell(SizedBox()),
              DataCell(SizedBox()),
              DataCell(SizedBox()),
            ],
          ),
        );
      }

      // Group 1
      addDivider("▶ Undercarriage");
      for (final r in rows.where((r) => r.number >= 0 && r.number <= 1)) {
        tableRows.add(_buildRow(r));
      }

      // Group 2
      addDivider("▶ Blade");
      for (final r in rows.where((r) => r.number >= 2 && r.number <= 5)) {
        tableRows.add(_buildRow(r));
      }

      // Group 3
      addDivider("▶ Ripper");
      for (final r in rows.where((r) => r.number >= 6 && r.number <= 9)) {
        tableRows.add(_buildRow(r));
      }

      // Group 4
      addDivider("▶ Hydraulic System");
      for (final r in rows.where((r) => r.number >= 10 && r.number <= 14)) {
        tableRows.add(_buildRow(r));
      }

      // Group 5
      addDivider("▶ Cylinder and Hose");
      for (final r in rows.where((r) => r.number >= 15 && r.number <= 22)) {
        tableRows.add(_buildRow(r));
      }

      // Group 6
      addDivider("▶ Frame / Chasis");
      for (final r in rows.where((r) => r.number >= 23 && r.number <= 25)) {
        tableRows.add(_buildRow(r));
      }

      // Group 6
      addDivider("▶ Engine");
      for (final r in rows.where((r) => r.number >= 26 && r.number <= 37)) {
        tableRows.add(_buildRow(r));
      }

      // Group 7
      addDivider("▶ Transmission and Final Drive");
      for (final r in rows.where((r) => r.number >= 38 && r.number <= 43)) {
        tableRows.add(_buildRow(r));
      }

      // Group 8
      addDivider("▶ Cabin");
      for (final r in rows.where((r) => r.number >= 44 && r.number <= 52)) {
        tableRows.add(_buildRow(r));
      }

      // Group 9
      addDivider("▶ Electrical");
      for (final r in rows.where((r) => r.number >= 53 && r.number <= 60)) {
        tableRows.add(_buildRow(r));
      }

      // Group 10
      addDivider("▶ Fuel / Oil / Lube");
      for (final r in rows.where((r) => r.number >= 61 && r.number <= 64)) {
        tableRows.add(_buildRow(r));
      }

      return tableRows;
    }

    final table = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 24,
            headingRowHeight: 48,
            dataRowMinHeight: 35,
            dataRowMaxHeight: 50,
            columns: const [
              DataColumn(label: Text('No')),
              DataColumn(label: Text('Inspection Thing')),
              DataColumn(label: Text('Inspction Ref')),
              DataColumn(label: Text('Condition')),
              DataColumn(label: Text('Notes')), // ✅ NEW COLUMN
              DataColumn(label: Text('Action')),
              DataColumn(label: Text('Action Date')),
              DataColumn(label: Text('Photo')),
            ],
            rows: _buildTableRows(),
          ),
        ),
      ),
    );

    if (!widget.showActions) {
      return Padding(padding: const EdgeInsets.all(8), child: table);
    }

    return Stack(
      children: [
        Column(
          children: [
            _buildTopForm(), // 🔼 form fields above the table
            const Divider(),
            Expanded(child: table),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.cyan[50]!, // 🌊 Cyan
                    Colors.green[50]!, // 🌿 Green
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                ),
              ),
              child: Row(
                children: [
                  //----------------------------> UPLOAD BUTTON <--------------------------
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (_isUploading) return;
                      setState(() {
                        _isUploading = true;
                      });
                      try {
                        // Export as Excel including topForm
                        final directory = await getExternalStorageDirectory();
                        String dirPath =
                            directory?.path ?? '/storage/emulated/0/Download';

                        // 🔹 Collect files to include
                        final List<File> filesToZip = [];

                        // Collect top form values
                        final topForm = {
                          'form_type': 'grader_form',
                          'form_id': widget.topForm?['form_id'] ?? '',
                          'catatan_kendaraan': _vehicleNoController.text,
                          'hm_km': _hmKmController.text,
                          'lokasi_inspeksi': _lokasiController.text,
                          'inspektor': _selectedOption ?? '',
                          'unit': _selectedOption2 ?? '',
                          'site_project': _siteProjectController.text,
                          'tanggal': _selectedDate?.toIso8601String() ?? '',
                          'jam_inspeksi': _selectedTime == null
                              ? ''
                              : '${_selectedTime!.hour}:${_selectedTime!.minute}',
                          'foto_extra': _selectedPhoto?.path ?? '',
                        };

                        // Build export filename using inspection date and time
                        String inspectionDate = topForm['tanggal'] ?? '';
                        String inspectionTime = topForm['jam_inspeksi'] ?? '';
                        // Format inspectionDate to only take the date part (YYYY-MM-DD)
                        if (inspectionDate.contains('T')) {
                          inspectionDate = inspectionDate.split('T').first;
                        }
                        inspectionDate = inspectionDate
                            .replaceAll(':', '-')
                            .replaceAll(' ', '_');
                        inspectionTime = inspectionTime
                            .replaceAll(':', '-')
                            .replaceAll(' ', '_');

                        final username = await _getUsername() ?? "guest";
                        final exportFileName =
                            '${username}_grader_form_${inspectionDate}_${inspectionTime}.xlsx';
                        final excelFile = File('$dirPath/$exportFileName');

                        // Create Excel workbook
                        var excel = Excel.createExcel();
                        var sheet = excel['Sheet1'];

                        // Export extra photo (top form)
                        String extraPhotoFilename = '';
                        if (topForm['foto_extra'] != null &&
                            topForm['foto_extra'].toString().isNotEmpty) {
                          final extraPhotoFile = File(topForm['foto_extra']);
                          if (await extraPhotoFile.exists()) {
                            final ext =
                                extraPhotoFile.uri.pathSegments.last.contains('.')
                                ? extraPhotoFile.uri.pathSegments.last.substring(
                                    extraPhotoFile.uri.pathSegments.last.lastIndexOf(
                                      '.',
                                    ),
                                  )
                                : '';
                            extraPhotoFilename =
                                'grader_form_${inspectionDate}_${inspectionTime}_topform$ext';
                            final exportExtraPhotoPath =
                                '$dirPath/$extraPhotoFilename';
                            await extraPhotoFile.copy(exportExtraPhotoPath);

                            filesToZip.add(File(exportExtraPhotoPath));
                            topForm['foto_extra'] = extraPhotoFilename;
                          }
                        }

                        // Add top form header
                        int rowIndex = 0;
                        int colIndex = 0;
                        for (var key in topForm.keys) {
                          sheet
                              .cell(
                                CellIndex.indexByColumnRow(
                                  columnIndex: colIndex,
                                  rowIndex: rowIndex,
                                ),
                              )
                              .value = TextCellValue(
                            key == 'catatan_kendaraan' ? 'catatan_kendaraan' : key,
                          );
                          colIndex++;
                        }

                        // Add top form values
                        rowIndex++;
                        colIndex = 0;
                        for (var value in topForm.values) {
                          sheet
                              .cell(
                                CellIndex.indexByColumnRow(
                                  columnIndex: colIndex,
                                  rowIndex: rowIndex,
                                ),
                              )
                              .value = TextCellValue(
                            value.toString(),
                          );
                          colIndex++;
                        }

                        // Add blank row
                        rowIndex += 2;

                        // Add inspection rows header
                        final headers = [
                          'No',
                          'Ref',
                          'Thing',
                          'Condition',
                          'Action',
                          'Action Date',
                          'Notes',
                          'Photo Filename',
                        ];
                        colIndex = 0;
                        for (var header in headers) {
                          sheet
                              .cell(
                                CellIndex.indexByColumnRow(
                                  columnIndex: colIndex,
                                  rowIndex: rowIndex,
                                ),
                              )
                              .value = TextCellValue(
                            header,
                          );
                          colIndex++;
                        }

                        // Add inspection rows
                        for (final row in rows) {
                          rowIndex++;
                          colIndex = 0;

                          String photoFilename = '';
                          if (row.photo?.path != null && row.photo!.path.isNotEmpty) {
                            final photoFile = File(row.photo!.path);
                            if (await photoFile.exists()) {
                              final ext =
                                  photoFile.uri.pathSegments.last.contains('.')
                                  ? photoFile.uri.pathSegments.last.substring(
                                      photoFile.uri.pathSegments.last.lastIndexOf(
                                        '.',
                                      ),
                                    )
                                  : '';
                              photoFilename =
                                  'grader_form_${inspectionDate}_${inspectionTime}_row${row.number}$ext';
                              final exportPhotoPath = '$dirPath/$photoFilename';
                              await photoFile.copy(exportPhotoPath);
                              filesToZip.add(File(exportPhotoPath));
                            }
                          }

                          // Add row data
                          sheet
                              .cell(
                                CellIndex.indexByColumnRow(
                                  columnIndex: colIndex++,
                                  rowIndex: rowIndex,
                                ),
                              )
                              .value = TextCellValue(
                            row.number.toString(),
                          );
                          sheet
                              .cell(
                                CellIndex.indexByColumnRow(
                                  columnIndex: colIndex++,
                                  rowIndex: rowIndex,
                                ),
                              )
                              .value = TextCellValue(
                            row.inspectionRef,
                          );
                          sheet
                              .cell(
                                CellIndex.indexByColumnRow(
                                  columnIndex: colIndex++,
                                  rowIndex: rowIndex,
                                ),
                              )
                              .value = TextCellValue(
                            row.thing,
                          );
                          sheet
                              .cell(
                                CellIndex.indexByColumnRow(
                                  columnIndex: colIndex++,
                                  rowIndex: rowIndex,
                                ),
                              )
                              .value = TextCellValue(
                            row.condition,
                          );
                          sheet
                              .cell(
                                CellIndex.indexByColumnRow(
                                  columnIndex: colIndex++,
                                  rowIndex: rowIndex,
                                ),
                              )
                              .value = TextCellValue(
                            row.action,
                          );
                          sheet
                              .cell(
                                CellIndex.indexByColumnRow(
                                  columnIndex: colIndex++,
                                  rowIndex: rowIndex,
                                ),
                              )
                              .value = TextCellValue(
                            row.actionDate != null
                                ? row.actionDate!.toIso8601String()
                                : '',
                          );
                          sheet
                              .cell(
                                CellIndex.indexByColumnRow(
                                  columnIndex: colIndex++,
                                  rowIndex: rowIndex,
                                ),
                              )
                              .value = TextCellValue(
                            row.notes,
                          );
                          sheet
                              .cell(
                                CellIndex.indexByColumnRow(
                                  columnIndex: colIndex++,
                                  rowIndex: rowIndex,
                                ),
                              )
                              .value = TextCellValue(
                            photoFilename,
                          );
                        }

                        // Save Excel file
                        final excelData = excel.encode();
                        if (excelData != null) {
                          await excelFile.writeAsBytes(excelData);
                          filesToZip.add(excelFile);

                          // 🔹 Create ZIP
                          final archive = Archive();
                          for (final f in filesToZip) {
                            final bytes = await f.readAsBytes();
                            archive.addFile(
                              ArchiveFile(
                                f.uri.pathSegments.last,
                                bytes.length,
                                bytes,
                              ),
                            );
                          }

                          final zipEncoder = ZipEncoder();
                          final zipData = zipEncoder.encode(archive);

                          if (zipData == null) {
                            throw Exception("Failed to create ZIP data");
                          }

                          final zipFile = File(
                            '$dirPath/${username}_grader_form_${inspectionDate}_${inspectionTime}.zip',
                          );
                          await zipFile.writeAsBytes(zipData);

                          // 🔹 Upload ZIP
                          final request = http.MultipartRequest(
                            'POST',
                            Uri.parse('http://inspeksi.gmt.id:12345/upload'),
                          );
                          request.files.add(
                            await http.MultipartFile.fromPath('file', zipFile.path),
                          );
                          final response = await request.send();

                          if (response.statusCode == 200) {
                            for (final f in filesToZip) {
                              try {
                                if (await f.exists()) {
                                  await f.delete();
                                }
                              } catch (e) {
                                debugPrint("Failed to delete ${f.path}: $e");
                              }
                            }

                            // 🔹 Update Hive after successful upload
                            try {
                              final box = Hive.box('grader_forms');
                              final hiveKey = context
                                  .findAncestorWidgetOfExactType<GraderFormEditPage>()
                                  ?.hiveKey;

                              if (hiveKey != null) {
                                // 🔹 Get existing item from Hive
                                Map<String, dynamic> existing =
                                    Map<String, dynamic>.from(
                                      box.get(hiveKey, defaultValue: {}),
                                    );

                                // 🔹 Get the existing form map
                                Map<String, dynamic> topForm =
                                    Map<String, dynamic>.from(existing['form'] ?? {});

                                // 🔹 Update just one field inside topForm
                                topForm['is_uploaded'] = 'yes';

                                // 🔹 Rebuild result
                                final result = {
                                  'form': topForm,
                                  'inspection_rows':
                                      existing['inspection_rows'] ?? [],
                                };

                                // Optional: pretty print JSON
                                final jsonStr = const JsonEncoder.withIndent(
                                  '  ',
                                ).convert(result);
                                debugPrint("Updated Hive data: $jsonStr");

                                // 🔹 Save back to Hive
                                await box.put(hiveKey, result);
                                debugPrint(
                                  "Successfully updated is_uploaded to 'yes' in Hive",
                                );
                              } else {
                                debugPrint(
                                  "Error: hiveKey is missing. Cannot update data.",
                                );
                              }
                            } catch (e) {
                              debugPrint("Failed to update Hive: $e");
                              setState(() {
                                _isUploading = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Warning: Upload successful but failed to update local data: $e',
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              _isUploading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Uploaded: ${zipFile.path}')),
                            );
                          } else {
                            setState(() {
                              _isUploading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Upload failed: ${response.statusCode}',
                                ),
                              ),
                            );
                          }
                          setState(() {
                            _isUploading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Excel exported: ' + excelFile.path),
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          _isUploading = false;
                        });
                        debugPrint('Upload error: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Upload error: $e'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Upload'),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ],
        ),
        if (_isUploading)
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}
