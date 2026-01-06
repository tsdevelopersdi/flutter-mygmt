import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
class ExcavatorFormPage extends StatelessWidget {
  final List<InspectionRow>? initialRows;
  final void Function(List<InspectionRow> rows)? onSave;

  const ExcavatorFormPage({super.key, this.initialRows, this.onSave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Excavator Inspection Form'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 252, 220, 110),
                Color.fromARGB(255, 255, 145, 35),
              ], // yellow → orange
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: WorkingDocForm(initialRows: initialRows, onSave: onSave),
      ),
    );
  }
}

/// The embeddable form widget (no Scaffold).
class WorkingDocForm extends StatefulWidget {
  final List<InspectionRow>? initialRows;
  final void Function(List<InspectionRow> rows)? onSave;

  /// If true, shows Save and Reset buttons at the bottom.
  final bool showActions;

  const WorkingDocForm({
    super.key,
    this.initialRows,
    this.onSave,
    this.showActions = true,
  });

  @override
  State<WorkingDocForm> createState() => _WorkingDocFormState();
}

class _WorkingDocFormState extends State<WorkingDocForm> {
  final picker = ImagePicker();

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
    rows = (widget.initialRows ?? _defaultRows()).map((e) => e.copy()).toList();
  }

  // Future<void> _pickExtraDate() async {
  //   final now = DateTime.now();
  //   final picked = await showDatePicker(
  //     context: context,
  //     initialDate: now,
  //     firstDate: DateTime(now.year - 5),
  //     lastDate: DateTime(now.year + 5),
  //   );
  //   if (picked != null) setState(() => _selectedDate = picked);
  // }

  Future<void> _pickExtraDate() async {
    final now = DateTime.now();
    setState(() => _selectedDate = now);
  }

  Future<void> _pickExtraTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _pickExtraPhoto() async {
    final img = await picker.pickImage(source: ImageSource.camera); // 📸 camera
    if (img != null) setState(() => _selectedPhoto = img);
  }

  List<InspectionRow> _defaultRows() => [
    InspectionRow(
      number: 1,
      inspectionRef: 'Undercarriage',
      thing: 'Pemeriksaan dilakukan saat CTS',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),

    // >>> Bucket and GET
    InspectionRow(
      number: 2,
      inspectionRef: 'Pin/Bushing Arm',
      thing: 'Periksa pin/bushing dan grease',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 3,
      inspectionRef: 'Pin/Bushing Bucket Cyl',
      thing: 'Periksa pin/bushing dan grease',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 4,
      inspectionRef: 'Lips Shroud',
      thing: 'Periksa retak dan keausan',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 5,
      inspectionRef: 'Tooth Bucket',
      thing: 'Periksa keausan dan patah',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 6,
      inspectionRef: 'Side Cutter',
      thing: 'Periksa retak dan keausan',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 7,
      inspectionRef: 'Back Plate',
      thing: 'Periksa retak dan keausan',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),

    // >>> Boom
    InspectionRow(
      number: 8,
      inspectionRef: 'Pin/Bushing Boom-Chassis',
      thing: 'Periksa pin/bushing dan grease',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 9,
      inspectionRef: 'Pin/Bushing Boom Cyl - RH',
      thing: 'Periksa pin/bushing dan grease',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 10,
      inspectionRef: 'Pin/Bushing Boom Cyl - LH',
      thing: 'Periksa pin/bushing dan grease',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 11,
      inspectionRef: 'Pin/Bushing Arm Cyl',
      thing: 'Periksa pin/bushing dan grease',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),

    // >>> Arm
    InspectionRow(
      number: 12,
      inspectionRef: 'Pin/Bushing Arm-Boom',
      thing: 'Periksa pin/bushing dan grease',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 13,
      inspectionRef: 'Pin/Bushing Arm Cyl',
      thing: 'Periksa pin/bushing dan grease',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),

    // >>> Hydraulic System
    InspectionRow(
      number: 14,
      inspectionRef: 'Pompa hidrolik',
      thing: 'Periksa kebocoran dan tekanan pompa',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 15,
      inspectionRef: 'Hose Pompa Hidrolik (All)',
      thing: 'periksa kebocoran dan kekakuan',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 16,
      inspectionRef: 'Control Valve',
      thing: 'Periksa kebocoran oli',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 17,
      inspectionRef: 'Hose Control Valve (All)',
      thing: 'periksa kebocoran dan kekakuan',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 18,
      inspectionRef: 'Tangki Hidrolik',
      thing: 'Periksa tangki, breather dan kebocoran',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),

    // >>> Cylinder and Hose
    InspectionRow(
      number: 19,
      inspectionRef: 'Boom Cylinder - RH',
      thing: 'Periksa rod dan barrel',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 20,
      inspectionRef: 'Boom Cylinder - LH',
      thing: 'Periksa rod dan barrel',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 21,
      inspectionRef: 'Hose Boom Cyl - RH',
      thing: 'Periksa kebocoran dan kekakuan',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 22,
      inspectionRef: 'Hose Boom Cyl - LH',
      thing: 'Periksa kebocoran dan kekakuan',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 23,
      inspectionRef: 'Arm/Stick Cylinder',
      thing: 'Periksa rod dan barrel',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 24,
      inspectionRef: 'Hose Arm/Stick Cylinder',
      thing: 'Periksa kebocoran dan kekakuan',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 25,
      inspectionRef: 'Bucket Cylinder',
      thing: 'Periksa rod dan barrel',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 26,
      inspectionRef: 'Hose Bucket Cylinder',
      thing: 'Periksa kebocoran dan kekakuan',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),

    // >>> Frame/Chasis
    InspectionRow(
      number: 27,
      inspectionRef: 'Bushing Link H - RF',
      thing: 'Periksa pin/bushing dan grease',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 28,
      inspectionRef: 'Bushing Link H - RR',
      thing: 'Periksa pin/bushing dan grease',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 29,
      inspectionRef: 'Bushing Link H - LF',
      thing: 'Periksa pin/bushing dan grease',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 30,
      inspectionRef: 'Bushing Link H - LR',
      thing: 'Periksa pin/bushing dan grease',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 31,
      inspectionRef: 'Step/Ladder',
      thing: 'Periksa tangga dan bolt/nut',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 32,
      inspectionRef: 'Handrail',
      thing: 'Periksa handrail dan bolt/nut',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),

    // >>> Engine
    InspectionRow(
      number: 33,
      inspectionRef: 'Belt',
      thing: 'Periksa kondisi belt dan kekencangan',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 34,
      inspectionRef: 'Hose/Tube',
      thing: 'Periksa kebocoran',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 35,
      inspectionRef: 'Radiator Core',
      thing: 'Periksa kebersihan dan kebocoran',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 36,
      inspectionRef: 'Radiator Hose',
      thing: 'Periksa kebocoran dan kekakuan',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 37,
      inspectionRef: 'Turbocharge',
      thing: 'Periksa retak dan kebocoran oli',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 38,
      inspectionRef: 'Air Filter',
      thing: 'Periksa kebocoran dan bersihkan jika buntu',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 39,
      inspectionRef: 'Engine Mounting',
      thing: 'Periksa bolt/nut dan karet peredam',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 40,
      inspectionRef: 'Fuel Hose',
      thing: 'Periksa retak dan kebocoran oli',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 41,
      inspectionRef: 'Engine Start',
      thing: 'Periksa kemudahan start',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 42,
      inspectionRef: 'Engine noise',
      thing: 'Periksa suara engine idle dan stall',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 43,
      inspectionRef: 'Exhaust',
      thing: 'Periksa warna asap exhaust',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 44,
      inspectionRef: 'Emergency Shutdown',
      thing: 'Periksa Fungsi',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),

    // >>> Transmision and Final Drive
    InspectionRow(
      number: 45,
      inspectionRef: 'Transmisi',
      thing: 'Periksa kebocoran oli',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 46,
      inspectionRef: 'Torque Converter',
      thing: 'Periksa kebocoran oli',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 47,
      inspectionRef: 'Final Drive RH',
      thing: 'Periksa kebocoran oli',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 48,
      inspectionRef: 'Final Drive LH',
      thing: 'Periksa kebocoran oli',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),

    // >>> Cabin
    InspectionRow(
      number: 49,
      inspectionRef: 'Pintu & Jendela',
      thing: 'Periksa handle, plat dan engsel',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 50,
      inspectionRef: 'Steering/Handle',
      thing: 'Periksa fungsi',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 51,
      inspectionRef: 'Instrument/Gauge',
      thing: 'Periksa fungsi',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 52,
      inspectionRef: 'Hour meter / Kilometer',
      thing: 'Periksa fungsi',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 53,
      inspectionRef: 'Wiper',
      thing: 'Periksa fungsi',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 54,
      inspectionRef: 'Horn',
      thing: 'Periksa kekerasan suara',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 55,
      inspectionRef: 'Side Mirror',
      thing: 'Periksa kaca dan adjuster',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 56,
      inspectionRef: 'Seat belt',
      thing: 'Periksa kanvas dan kuncian',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 57,
      inspectionRef: 'Air Conditioner',
      thing: 'Periksa switch dan temperatur',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),

    // >>> Electrical
    InspectionRow(
      number: 58,
      inspectionRef: 'Wiring/Cable',
      thing: 'Periksa fungsi',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 59,
      inspectionRef: 'Head Lamp',
      thing: 'Periksa fungsi',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 60,
      inspectionRef: 'Work Lamp',
      thing: 'Periksa fungsi',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 61,
      inspectionRef: 'Rear Lamp',
      thing: 'Periksa fungsi',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 62,
      inspectionRef: 'Turn Lamp',
      thing: 'Periksa fungsi',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 63,
      inspectionRef: 'Baterai',
      thing: 'Periksa fungsi',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 64,
      inspectionRef: 'Baterai',
      thing: 'Periksa air batterai',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 65,
      inspectionRef: 'Baterai Switch',
      thing: 'Periksa fungsi',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),

    // >>> Fuel / Oil / Lube
    InspectionRow(
      number: 66,
      inspectionRef: 'Fuel Level',
      thing: 'Periksa level dan kondisi bahan bakar',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 67,
      inspectionRef: 'Hydraulic Oil Level',
      thing: 'Periksa level dan kondisi oli',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 68,
      inspectionRef: 'Engine Oil Level',
      thing: 'Periksa level dan kondisi oli',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
    InspectionRow(
      number: 69,
      inspectionRef: 'Grease Level',
      thing: 'Periksa level grease autolube',
      condition: 'good',
      notes: "",
      action: 'none',
      actionDate: null,
    ),
  ];

  Future<void> _pickDate(int i) async {
    final now = DateTime.now();
    final initial = rows[i].actionDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => rows[i].actionDate = picked);
  }

  Future<void> _pickPhoto(int i) async {
    final img = await picker.pickImage(source: ImageSource.camera); // 📸 camera
    if (img != null) setState(() => rows[i].photo = img);
  }

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

  void _resetValues() {
    setState(() {
      for (final r in rows) {
        r.condition = 'good';
        r.action = 'none';
        r.actionDate = null;
        r.photo = null;
      }
      _vehicleNoController.clear();
      _hmKmController.clear();
      _lokasiController.clear();
      _siteProjectController.clear();
      _selectedOption = null;
      _selectedOption2 = null;
      _selectedDate = null;
      _selectedTime = null;
      _selectedPhoto = null;
    });
  }

  void _save() {
    // Validation: For any row with action 'repair' or 'replace', actionDate and photo are mandatory
    for (final r in rows) {
      if ((r.action == 'repair' || r.action == 'replace')) {
        if (r.actionDate == null || r.photo == null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                'Row ${r.number}: Date and Photo are required for action "${r.action}".'
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }
    
    final missingTop = <String>[];
    if (_selectedDate == null) missingTop.add('Tanggal');
    if (_selectedTime == null) missingTop.add('Jam Inspeksi');
    if (_selectedPhoto == null) missingTop.add('Foto');
    if (_siteProjectController.text.trim().isEmpty) missingTop.add('Site Project');
    if (_lokasiController.text.trim().isEmpty) missingTop.add('Lokasi Inspeksi');
    if (missingTop.isNotEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Please provide: ${missingTop.join(', ')}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final box = Hive.box('excavator_forms');
    final formId = const Uuid().v4();
    final topForm = {
      'is_uploaded': 'no',
      'form_type': 'excavator_form',
      'form_id': formId,
      'nomor_kendaraan': _vehicleNoController.text,
      'hm_km': _hmKmController.text,
      'lokasi_inspeksi': _lokasiController.text,
      'inspektor': _selectedOption,
      'unit': _selectedOption2,
      'site_project': _siteProjectController.text,
      'tanggal': _selectedDate?.toIso8601String(),
      'jam_inspeksi': _selectedTime == null
          ? null
          : '${_selectedTime!.hour}:${_selectedTime!.minute}',
      'foto_extra': _selectedPhoto?.path,
    };

    // Collect table rows
    final rowData = rows.map((e) => e.toJson()).toList();

    // Merge everything into one JSON object
    final result = {'form': topForm, 'inspection_rows': rowData};
    box.add(result);

    final jsonStr = const JsonEncoder.withIndent('  ').convert(result);
    debugPrint(jsonStr);
    // box.add(result);

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('All form data captured (see console).')),
    );

    Navigator.of(context).pop();
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
        ), // light background color
        child: Padding(
          padding: const EdgeInsets.all(6),
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
                    ),
                  ),
                  _labeledField(
                    "HM/KM",
                    TextField(
                      controller: _hmKmController,
                      style: const TextStyle(fontSize: 11),
                      decoration: _decoration("Enter..."),
                    ),
                  ),
                  _labeledField(
                    "Lokasi Inspeksi",
                    TextField(
                      controller: _lokasiController,
                      style: const TextStyle(fontSize: 11),
                      decoration: _decoration("Enter..."),
                    ),
                  ),
                  _labeledField(
                    "Inspektor",
                    DropdownButtonFormField<String>(
                      value: _selectedOption, // Default to first option
                      isDense: true,
                      style: const TextStyle(fontSize: 11, color: Colors.black),
                      decoration: _decoration("Select..."),
                      items: ['Option A', 'Option B', 'Option C']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: null, // Disable interaction
                      disabledHint: _selectedOption != null
                          ? Text(_selectedOption!)
                          : null,
                    ),
                  ),
                  _labeledField(
                    "Pilih Unit",
                    DropdownButtonFormField<String>(
                      value: _selectedOption2,
                      isDense: true,
                      style: const TextStyle(fontSize: 11, color: Colors.black),
                      decoration: _decoration("Select..."),
                      items:
                          [
                                'EXC-320-06',
                                'EXD-520-01',
                                'EXD-520-02',
                                'EXD-520-03',
                                'EXD-520-04',
                                'EXD-520-05',
                                'EXD-800-01',
                                'EXD-800-02',
                                'EXD-800-03',
                                'EXH-350-02',
                                'EXH-350-04',
                                'EXH-350-05',
                                'EXH-470-05',
                                'EXH-470-09',
                                'EXK-400-04',
                                'EXK-400-07',
                                'EXK-400-08',
                                'EXY-1250-01',
                                'EXY-210-02',
                                'EXY-210-03',
                                'EXY-220-01',
                                'EXY-480-01',
                                'EXY-480-02',
                                'EXY-520-01',
                                'EXY-850-01',
                                'EXY-850-02',
                                'EXY-850-03',
                                'EXY-850-04',
                                'EXY-850-05',
                              ]
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _selectedOption2 = v),
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
                          onPressed: _pickExtraDate,
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
                          onPressed: _pickExtraTime,
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
                          onPressed: _pickExtraPhoto,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      );
    }

    DataRow _buildRow(InspectionRow r) {
      final i = rows.indexOf(r);
      return DataRow(
        cells: [
          DataCell(Text(r.number.toString())),
          DataCell(Text(r.inspectionRef)),
          DataCell(Text(r.thing)),
          DataCell(
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: r.condition,
                items: conditions.map((c) {
                  Color textColor;

                  switch (c) {
                    case "good":
                      textColor = Colors.blue[900]!;
                      break;
                    case "bad":
                      textColor = Colors.red[900]!;
                      break;
                    default:
                      textColor = Colors.black;
                  }

                  return DropdownMenuItem(
                    value: c,
                    child: Text(c, style: TextStyle(color: textColor)),
                  );
                }).toList(),
                onChanged: (v) =>
                    setState(() => r.condition = v ?? r.condition),
              ),
            ),
          ),
          DataCell(
            SizedBox(
              width: 120, // ✅ limit width so it doesn’t expand too much
              child: TextField(
                controller: TextEditingController(text: r.notes)
                  ..selection = TextSelection.collapsed(offset: r.notes.length),
                onChanged: (v) => r.notes = v,
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
                items: actions.map((a) {
                  Color textColor;

                  switch (a) {
                    case "repair":
                      textColor = Colors.orange;
                      break;
                    case "replace":
                      textColor = Colors.red;
                      break;
                    case "monitor":
                      textColor = Colors.green;
                      break;
                    default:
                      textColor = Colors.black;
                  }

                  return DropdownMenuItem(
                    value: a,
                    child: Text(a, style: TextStyle(color: textColor)),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    r.action = v ?? r.action;
                    if (r.action == "none" || r.action == "monitor") {
                      r.photo = null;
                      r.actionDate = null;
                    }
                  });
                },
              ),
            ),
          ),

          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (r.actionDate != null &&
                    r.action != "none" &&
                    r.action != "monitor")
                  Text(_fmtDate(r.actionDate)),
                const SizedBox(width: 8),
                // FilledButton.tonal(
                //   onPressed: () => _pickDate(i),
                //   child: const Text('Pick'),
                // ),
                (r.action == "repair" || r.action == "replace")
                    ? FilledButton.tonal(
                        onPressed: () => _pickDate(i),
                        child: const Text('Pick'),
                      )
                    : FilledButton.tonal(
                        onPressed: null,
                        child: const Text('Pick'),
                      ),

                if (r.actionDate != null &&
                    r.action != "none" &&
                    r.action != "monitor")
                  IconButton(
                    tooltip: 'Clear date',
                    onPressed: () => setState(() => r.actionDate = null),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
          ),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (r.photo != null &&
                    r.action != "none" &&
                    r.action != "monitor")
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
                (r.action == "repair" || r.action == "replace")
                    ? FilledButton.tonalIcon(
                        onPressed: () => _pickPhoto(i),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Choose'),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: null,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Choose'),
                      ),
                if (r.photo != null &&
                    r.action != "none" &&
                    r.action != "monitor")
                  IconButton(
                    tooltip: 'Remove photo',
                    onPressed: () => setState(() => r.photo = null),
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
            // color: MaterialStatePropertyAll(Colors.grey.shade300),
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
      addDivider("▶ Bucket and GET");
      for (final r in rows.where((r) => r.number >= 2 && r.number <= 7)) {
        tableRows.add(_buildRow(r));
      }

      // Group 3
      addDivider("▶ Boom");
      for (final r in rows.where((r) => r.number >= 8 && r.number <= 11)) {
        tableRows.add(_buildRow(r));
      }

      // Group 4
      addDivider("▶ Arm");
      for (final r in rows.where((r) => r.number >= 12 && r.number <= 13)) {
        tableRows.add(_buildRow(r));
      }

      // Group 5
      addDivider("▶ Hydraulic System");
      for (final r in rows.where((r) => r.number >= 14 && r.number <= 18)) {
        tableRows.add(_buildRow(r));
      }

      // Group 6
      addDivider("▶ Cylinder and Hose");
      for (final r in rows.where((r) => r.number >= 19 && r.number <= 26)) {
        tableRows.add(_buildRow(r));
      }

      // Group 6
      addDivider("▶ Frame / Chasis");
      for (final r in rows.where((r) => r.number >= 27 && r.number <= 32)) {
        tableRows.add(_buildRow(r));
      }

      // Group 7
      addDivider("▶ Engine");
      for (final r in rows.where((r) => r.number >= 33 && r.number <= 44)) {
        tableRows.add(_buildRow(r));
      }

      // Group 8
      addDivider("▶ Transmision and Final Drive");
      for (final r in rows.where((r) => r.number >= 45 && r.number <= 48)) {
        tableRows.add(_buildRow(r));
      }

      // Group 9
      addDivider("▶ Cabin");
      for (final r in rows.where((r) => r.number >= 49 && r.number <= 57)) {
        tableRows.add(_buildRow(r));
      }

      addDivider("▶ Electrical");
      for (final r in rows.where((r) => r.number >= 58 && r.number <= 65)) {
        tableRows.add(_buildRow(r));
      }

      // Group 9
      addDivider("▶ Fuel / Oil / Lube");
      for (final r in rows.where((r) => r.number >= 66 && r.number <= 69)) {
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

    // return Column(
    //   children: [
    //     _buildTopForm(), // 🔼 form fields above the table
    //     const Divider(),
    //     Expanded(child: table),
    //     const SizedBox(height: 8),
    //     Padding(
    //       padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    //       child: Row(
    //         children: [
    //           FilledButton.icon(
    //             onPressed: _save,
    //             icon: const Icon(Icons.save),
    //             label: const Text('Save'),
    //           ),
    //           const SizedBox(width: 12),
    //           OutlinedButton.icon(
    //             onPressed: _resetValues,
    //             icon: const Icon(Icons.refresh),
    //             label: const Text('Reset Values'),
    //           ),
    //         ],
    //       ),
    //     ),
    //   ],
    // );

    return Column(
      children: [
        _buildTopForm(), // 🔼 form fields above the table
        const Divider(),
        Expanded(child: table),
        const SizedBox(height: 8),

        // 👇 Gradient background for bottom buttons
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
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _resetValues,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Values'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
