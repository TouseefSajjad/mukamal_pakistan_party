import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final searchController = TextEditingController();
  String search = "";

  final user = FirebaseAuth.instance.currentUser;

  String chatId(String a, String b) {
    return a.hashCode <= b.hashCode ? "${a}_$b" : "${b}_$a";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Members Chat"),
        backgroundColor: Colors.green,
      ),

      body: Column(
        children: [

          // 🔍 SEARCH
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: "Search member by name or role",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() {
                  search = val.toLowerCase();
                });
              },
            ),
          ),

          // 👥 USERS LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .where("membership_status", isEqualTo: "approved")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs;

                final filtered = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'].toString().toLowerCase();
                  final role = data['role'].toString().toLowerCase();

                  return name.contains(search) || role.contains(search);
                }).toList();

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final data =
                    filtered[index].data() as Map<String, dynamic>;

                    if (data['uid'] == user!.uid) {
                      return const SizedBox();
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Text(
                          data['name'][0].toString().toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),

                      title: Text(data['name']),
                      subtitle: Text(data['role']),

                      trailing: const Icon(Icons.chat, color: Colors.green),

                      onTap: () {
                        String id = chatId(user!.uid, data['uid']);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(
                              chatId: id,
                              receiverId: data['uid'],
                              receiverName: data['name'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}