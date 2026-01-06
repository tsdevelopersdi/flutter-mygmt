// // import 'package:inspection_app_gmt_3/forms/adt_form_edit_page.dart';
// import 'package:inspection_app_gmt_3/forms/excavator_form_edit_page.dart';
// import 'package:inspection_app_gmt_3/forms/excavator_form_page.dart';
// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';

// class ExcavatorListPage extends StatelessWidget {
//   const ExcavatorListPage({Key? key}) : super(key: key);

//   Future<Box> _openFormsBox() async {
//     if (!Hive.isBoxOpen('excavator_forms')) {
//       if (!Hive.isAdapterRegistered(0)) {
//         // quick check for initialization
//         await Hive.initFlutter();
//       }
//       return await Hive.openBox('excavator_forms');
//     }
//     return Hive.box('excavator_forms');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<Box>(
//       future: _openFormsBox(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState != ConnectionState.done) {
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }
//         if (snapshot.hasError) {
//           return Scaffold(
//             body: Center(
//               child: Text('Error opening Hive box: \n${snapshot.error}'),
//             ),
//           );
//         }
//         final formsBox = snapshot.data!;
//         return Scaffold(
//           appBar: AppBar(title: const Text("Excavator Forms")),
//           body: ValueListenableBuilder(
//             valueListenable: formsBox.listenable(),
//             builder: (context, Box box, _) {
//               final allForms = box.values.toList();
//               final excavatorForms = allForms.where((form) {
//                 final f = form as Map;
//                 return f["form"]?["form_type"] == "excavator_form";
//               }).toList();

//               if (excavatorForms.isEmpty) {
//                 return const Center(child: Text("No Excavator forms found."));
//               }

//               return ListView.builder(
//                 itemCount: excavatorForms.length,
//                 itemBuilder: (context, index) {
//                   final form = excavatorForms[index] as Map;
//                   final formData = form["form"] as Map;

//                   // format tanggal
//                   String inspectionDate = formData["tanggal"] ?? '';
//                   if (inspectionDate.contains('T')) {
//                     inspectionDate = inspectionDate.split('T').first;
//                   }

//                   bool hasBadCondition = false;

//                   // Check for expired "bad" rows
//                   bool hasExpiredBadRow = false;
//                   final rows = form["inspection_rows"] as List?;
//                   if (rows != null) {
//                     for (final row in rows) {
//                       final r = row as Map;
//                       final condition = r["condition"];
//                       final actionDateStr = r["action_date"];

//                       if (condition == "bad") {
//                         hasBadCondition = true;
//                       }

//                       if (condition == "bad" && actionDateStr != null) {
//                         try {
//                           final actionDate = DateTime.parse(actionDateStr);
//                           // hasBadCondition = true;
//                           if (actionDate.isBefore(DateTime.now())) {
//                             hasExpiredBadRow = true;
//                             break;
//                           }
//                         } catch (e) {
//                           // ignore parse errors
//                         }
//                       }
//                     }
//                   }

//                   // 🎨 decide background decoration
//                   final BoxDecoration decoration;
//                   if (hasBadCondition == true && hasExpiredBadRow == false) {
//                     decoration = BoxDecoration(
//                       color: Colors.yellow[700], // solid yellow background
//                       borderRadius: BorderRadius.circular(12),
//                     );
//                   } else if (hasExpiredBadRow == true &&
//                       hasBadCondition == true) {
//                     decoration = BoxDecoration(
//                       color: Colors.red[700], // solid red background
//                       borderRadius: BorderRadius.circular(12),
//                     );
//                   } else {
//                     decoration = BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [Colors.blueAccent[100]!, Colors.green[50]!],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                       borderRadius: BorderRadius.circular(12),
//                     );
//                   }

//                   return Card(
//                     margin: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 6,
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Container(
//                       decoration: decoration,
//                       child: ListTile(
//                         tileColor: Colors.transparent, // let gradient show
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         title: Text(
//                           "Form Excavator ${index + 1}",
//                           style: const TextStyle(
//                             fontWeight: FontWeight.bold,
//                             color: Colors.black,
//                           ),
//                         ),

//                         subtitle: Text(
//                           "Catatan Kendaraan: ${formData["nomor_kendaraan"]}\n"
//                           "Waktu: ${formData["jam_inspeksi"]}\n"
//                           "Uploaded: ${formData["is_uploaded"]}\n"
//                           "Tanggal: $inspectionDate",
//                           style: const TextStyle(color: Colors.black87),
//                         ),
//                         trailing: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             // ✅ checkmark OR empty space
//                             formData["is_uploaded"] == "yes"
//                                 ? const Icon(
//                                     Icons.check_circle,
//                                     color: Colors.green,
//                                   )
//                                 : const SizedBox.shrink(), // nothing
//                             // spacing (only if uploaded is "yes")
//                             formData["is_uploaded"] == "yes"
//                                 ? const SizedBox(width: 8)
//                                 : const SizedBox.shrink(),

//                             IconButton(
//                               icon: const Icon(Icons.delete, color: Colors.red),
//                               onPressed: () {
//                                 // confirm delete dialog
//                                 showDialog(
//                                   context: context,
//                                   builder: (ctx) => AlertDialog(
//                                     title: const Text("Delete Form"),
//                                     content: const Text(
//                                       "Are you sure you want to delete this form?",
//                                     ),
//                                     actions: [
//                                       TextButton(
//                                         onPressed: () => Navigator.pop(ctx),
//                                         child: const Text("Cancel"),
//                                       ),
//                                       TextButton(
//                                         onPressed: () {
//                                           // remove from Hive
//                                           final key = box.keyAt(index);
//                                           box.delete(key);

//                                           Navigator.pop(ctx); // close dialog
//                                           ScaffoldMessenger.of(
//                                             context,
//                                           ).showSnackBar(
//                                             const SnackBar(
//                                               content: Text("Form deleted"),
//                                             ),
//                                           );
//                                         },
//                                         child: const Text(
//                                           "Delete",
//                                           style: TextStyle(color: Colors.red),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               },
//                             ),
//                             const Icon(
//                               Icons.arrow_forward_ios,
//                               color: Colors.black54,
//                             ),
//                           ],
//                         ),
//                         onTap: () {
//                           final hiveKey = box.keyAt(index);
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => ExcavatorFormEditPage(
//                                 formJson: form, // pass full JSON here
//                                 hiveKey: hiveKey, // pass the key
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                   );
//                 },
//               );
//             },
//           ),
//           floatingActionButton: FloatingActionButton(
//             heroTag: 'excavator_list_fab_main',
//             onPressed: () {
//               Navigator.of(context).push(
//                 MaterialPageRoute(
//                   builder: (context) => const ExcavatorFormPage(),
//                 ),
//               );
//             },
//             child: const Icon(Icons.add),
//           ),
//         );
//       },
//     );
//   }
// }

import 'package:inspection_app_gmt_3/forms/excavator_form_edit_page.dart';
import 'package:inspection_app_gmt_3/forms/excavator_form_page.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ExcavatorListPage extends StatefulWidget {
  const ExcavatorListPage({Key? key}) : super(key: key);

  @override
  State<ExcavatorListPage> createState() => _ExcavatorListPageState();
}

class _ExcavatorListPageState extends State<ExcavatorListPage> {
  String _searchQuery = "";
  Future<Box>? _formsBoxFuture;

  @override
  void initState() {
    super.initState();
    _initializeBox();
  }

  void _initializeBox() {
    _formsBoxFuture = _openFormsBox();
  }

  Future<Box> _openFormsBox() async {
    try {
      if (!Hive.isBoxOpen('excavator_forms')) {
        if (!Hive.isAdapterRegistered(0)) {
          await Hive.initFlutter();
        }
        return await Hive.openBox('excavator_forms');
      }
      return Hive.box('excavator_forms');
    } catch (e) {
      print('Error opening Hive box: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Excavator Forms"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              style: const TextStyle(
                color: Colors.black,
              ), // 👈 ensure text is visible
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Search by Nomor Kendaraan / Tanggal...",
                hintStyle: const TextStyle(
                  color: Colors.grey,
                ), // 👈 visible hint
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.black54,
                ), // 👈 visible icon
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _formsBoxFuture == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing database...'),
                ],
              ),
            )
          : FutureBuilder<Box>(
              future: _formsBoxFuture!,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error opening database:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _initializeBox();
                            });
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                final formsBox = snapshot.data!;
                return _buildBodyContent(formsBox);
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'excavator_list_fab_main',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ExcavatorFormPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBodyContent(Box formsBox) {
    return ValueListenableBuilder(
      valueListenable: formsBox.listenable(),
      builder: (context, Box box, _) {
        final allKeys = box.keys.toList();
        final allForms = box.values.toList();

        final ExcavatorFormsWithKeys = [];
        for (int i = 0; i < allForms.length; i++) {
          final form = allForms[i] as Map;
          if (form["form"]?["form_type"] == "excavator_form") {
            ExcavatorFormsWithKeys.add({'key': allKeys[i], 'form': form});
          }
        }

        final filteredForms = ExcavatorFormsWithKeys.where((item) {
          final form = item['form'] as Map;
          final formData = form["form"] as Map;
          final nomor = (formData["nomor_kendaraan"] ?? "")
              .toString()
              .toLowerCase();
          final tanggal = (formData["tanggal"] ?? "").toString().toLowerCase();
          final jam = (formData["jam_inspeksi"] ?? "").toString().toLowerCase();

          return nomor.contains(_searchQuery) ||
              tanggal.contains(_searchQuery) ||
              jam.contains(_searchQuery);
        }).toList();

        if (filteredForms.isEmpty) {
          return const Center(
            child: Text("No matching Excavator forms found."),
          );
        }

        return ListView.builder(
          itemCount: filteredForms.length,
          itemBuilder: (context, index) {
            final item = filteredForms[index];
            final form = item['form'] as Map;
            final hiveKey = item['key'];
            final formData = form["form"] as Map;

            String inspectionDate = formData["tanggal"] ?? '';
            if (inspectionDate.contains('T')) {
              inspectionDate = inspectionDate.split('T').first;
            }

            bool hasBadCondition = false;
            bool hasExpiredBadRow = false;

            final rows = form["inspection_rows"] as List?;
            if (rows != null) {
              for (final row in rows) {
                final r = row as Map;
                final condition = r["condition"];
                final actionDateStr = r["action_date"];

                if (condition == "bad") {
                  hasBadCondition = true;
                }

                if (condition == "bad" && actionDateStr != null) {
                  try {
                    final actionDate = DateTime.parse(actionDateStr);
                    if (actionDate.isBefore(DateTime.now())) {
                      hasExpiredBadRow = true;
                      break;
                    }
                  } catch (_) {}
                }
              }
            }

            final BoxDecoration decoration;
            if (hasBadCondition && !hasExpiredBadRow) {
              decoration = BoxDecoration(
                color: Colors.yellow[700],
                borderRadius: BorderRadius.circular(12),
              );
            } else if (hasExpiredBadRow && hasBadCondition) {
              decoration = BoxDecoration(
                color: Colors.red[700],
                borderRadius: BorderRadius.circular(12),
              );
            } else {
              decoration = BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent[100]!, Colors.green[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              );
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: decoration,
                child: ListTile(
                  tileColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(
                    "Form Excavator ${index + 1}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    "Catatan Kendaraan: ${formData["nomor_kendaraan"]}\n"
                    "Waktu: ${formData["jam_inspeksi"]}\n"
                    "Uploaded: ${formData["is_uploaded"]}\n"
                    "Tanggal: $inspectionDate",
                    style: const TextStyle(color: Colors.black87),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      formData["is_uploaded"] == "yes"
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const SizedBox.shrink(),
                      formData["is_uploaded"] == "yes"
                          ? const SizedBox(width: 8)
                          : const SizedBox.shrink(),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Delete Form"),
                              content: const Text(
                                "Are you sure you want to delete this form?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    box.delete(hiveKey);
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Form deleted"),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Delete",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExcavatorFormEditPage(
                          formJson: form,
                          hiveKey: hiveKey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
