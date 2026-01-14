import 'package:flutter/material.dart';

class CreateRideScreen extends StatelessWidget {
  const CreateRideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offer a Ride')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
             const TextField(
               decoration: InputDecoration(
                 labelText: 'From',
                 prefixIcon: Icon(Icons.my_location),
               ),
             ),
             const SizedBox(height: 16),
             const TextField(
               decoration: InputDecoration(
                 labelText: 'To',
                 prefixIcon: Icon(Icons.location_on),
               ),
             ),
             const SizedBox(height: 16),
             // Date Picker Placeholder
             Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 border: Border.all(color: Colors.grey),
                 borderRadius: BorderRadius.circular(12),
               ),
               child: const Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text('Today, 10:00 AM'),
                   Icon(Icons.calendar_today),
                 ],
               ),
             ),
             const SizedBox(height: 16),
             // Only show for female users (Mock: assume female for now or pass actual user)
             // In real app, we check: if (currentUser.gender == 'FEMALE')
             Row(
               children: [
                 const Expanded(child: Text('Female Passengers Only', style: TextStyle(fontWeight: FontWeight.bold))),
                 Switch(
                   value: false, 
                   onChanged: (val){},
                   activeColor: Colors.pink,
                 )
               ],
             ),
             const Spacer(),
             ElevatedButton(
               onPressed: () {},
               child: const Text('Publish Ride'),
             )
          ],
        ),
      ),
    );
  }
}
