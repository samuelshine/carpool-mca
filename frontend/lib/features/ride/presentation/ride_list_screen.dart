import 'package:flutter/material.dart';

class RideListScreen extends StatelessWidget {
  const RideListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rides'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5, // Mock data
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: const Text('Ride to Central Campus'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      Text('10:00 AM • ${index + 2} seats left'),
                    ],
                  ),
                  if (index % 2 == 0) ...[
                     const SizedBox(height: 4),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                       decoration: BoxDecoration(
                         color: Colors.pink.shade100,
                         borderRadius: BorderRadius.circular(4)
                       ),
                       child: const Text('Females Only', style: TextStyle(fontSize: 10, color: Colors.pink)),
                     )
                  ]
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () {}, 
                child: const Text('Join'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(60, 36)),
              ),
            ),
          );
        },
      ),
    );
  }
}
