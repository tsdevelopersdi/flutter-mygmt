import 'package:flutter/material.dart';

class MenuPage extends StatelessWidget {
  final void Function(BuildContext context, int sublistIndex)? onNavigate;
  const MenuPage({Key? key, this.onNavigate}) : super(key: key);

  final List<_MenuItem> items = const [
    _MenuItem('Articulated Dump Truck', image: AssetImage('assets/images/adt_2.png'), sublistIndex: 3),
    _MenuItem('Excavator', image: AssetImage('assets/images/excavator_2.png'), sublistIndex: 4),
    _MenuItem('Bulldozer', image: AssetImage('assets/images/dozer_2.png'), sublistIndex: 5),
    _MenuItem('Grader', image: AssetImage('assets/images/grader_2.png'), sublistIndex: 6),
    _MenuItem('High Dump', image: AssetImage('assets/images/hd_2.png'), sublistIndex: 7),
    _MenuItem('High Dump Truck', image: AssetImage('assets/images/hdt_2.png'), sublistIndex: 8),
    _MenuItem('Dump Truck', image: AssetImage('assets/images/dt_2.png'), sublistIndex: 9),
    _MenuItem('Wheel Loader', image: AssetImage('assets/images/wl_2.png'), sublistIndex: 10),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              onTap: () {
                if (onNavigate != null && item.sublistIndex != null) {
                  onNavigate!(context, item.sublistIndex!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Clicked ${item.label}')),
                  );
                }
              },
              child: Card(
                elevation: 4,
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
                      Icon(item.icon!, size: 90, color: Theme.of(context).primaryColor),
                    const SizedBox(height: 18),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize:16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final IconData? icon;
  final ImageProvider? image;
  final int? sublistIndex;
  const _MenuItem(this.label, {this.icon, this.image, this.sublistIndex});
}
