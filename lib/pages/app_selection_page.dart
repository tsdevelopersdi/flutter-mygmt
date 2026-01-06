import 'package:flutter/material.dart';

class AppSelectionPage extends StatelessWidget {
  final void Function(BuildContext context, String appType)? onNavigate;
  
  const AppSelectionPage({
    Key? key,
    this.onNavigate,
  }) : super(key: key);

  final List<_AppMenuItem> items = const [
    _AppMenuItem(
      'Mobile Attendance',
      appType: 'attendance',
      image: AssetImage('assets/images/calendar.png'),
      description: 'Track your attendance and work activities',
      isEnabled: true,
    ),
    _AppMenuItem(
      'Mobile Inspection',
      appType: 'inspection',
      image: AssetImage('assets/images/excavator_2.png'),
      description: 'Inspect and manage equipment',
      isEnabled: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Choose Application'),
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: item.isEnabled
                  ? () {
                      if (onNavigate != null) {
                        onNavigate!(context, item.appType);
                      } else {
                        Navigator.of(context).pushNamed(
                          item.appType == 'attendance' ? '/attendance' : '/menu',
                        );
                      }
                    }
                  : null,
              child: Opacity(
                opacity: item.isEnabled ? 1.0 : 0.5,
                child: Card(
                  elevation: item.isEnabled ? 4 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.image != null)
                      Image(
                        image: item.image!,
                        width: 90,
                        height: 90,
                      )
                    else if (item.icon != null)
                      Icon(
                        item.icon!,
                        size: 90,
                        color: Theme.of(context).primaryColor,
                      ),
                    const SizedBox(height: 18),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        item.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AppMenuItem {
  final String label;
  final String appType;
  final IconData? icon;
  final ImageProvider? image;
  final String description;
  final bool isEnabled;

  const _AppMenuItem(
    this.label, {
    required this.appType,
    this.icon,
    this.image,
    this.description = '',
    this.isEnabled = true,
  });
}
