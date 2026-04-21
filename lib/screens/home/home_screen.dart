import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mukammalpakistanparty/ config/app_theme.dart';
import 'package:mukammalpakistanparty/screens/auth/login_screen.dart';
import 'package:marquee/marquee.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    setState(() {
      userData = doc.data();
    });
  }

  // ================= LOGOUT =================

  Future<void> confirmLogout() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: AppTheme.primaryButton,
            onPressed: () async {
              Navigator.pop(context);
              await logout();
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await FirebaseAuth.instance.signOut();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ================= DELETE ACCOUNT =================

  Future<void> showDeleteDialog() async {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter your password to permanently delete your account.",
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "Password",
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await deleteAccount(passwordController.text.trim());
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> deleteAccount(String password) async {
    try {
      if (user == null) return;

      final email = user!.email;

      if (email == null || password.isEmpty) {
        throw Exception("Email or password required");
      }

      // 🔥 RE-AUTH
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user!.reauthenticateWithCredential(credential);

      // 🔥 DELETE FIRESTORE
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .delete();

      // 🔥 DELETE AUTH
      await user!.delete();

      // 🔥 CLEAR STORAGE
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account deleted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,

      appBar: AppBar(
        title: const Text("Mukamal Pakistan Party"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: confirmLogout,
          )
        ],
      ),

      body: userData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔥 HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: AppTheme.primaryGreen,
              child: Column(
                children: [
                  Image.asset(
                    "assets/logo.png",
                    height: 80,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 25,
                    child: Marquee(
                      text: "مکمل پاکستان پارٹی کا نعرہ ایمان ،اتحاد ،تنظیم اور عدل میں مستقبل ہمارا",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize:15,
                        fontWeight: FontWeight.bold,
                      ),
                      scrollAxis: Axis.horizontal,
                      blankSpace: 50,
                      velocity: 30,
                      pauseAfterRound: const Duration(seconds: 2),
                      startPadding: 10,
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 15),

            // 🔥 USER CARD
            // Padding(
            //   padding: const EdgeInsets.all(12),
            //   child: Card(
            //     child: ListTile(
            //       leading: const Icon(Icons.person,
            //           color: AppTheme.primaryGreen),
            //       title: Text(userData!['name'] ?? "User"),
            //       subtitle: Text(userData!['email'] ?? ""),
            //       trailing: Text(
            //         userData!['membership_status'] ?? "pending",
            //         style: const TextStyle(
            //           color: AppTheme.accentPink,
            //           fontWeight: FontWeight.bold,
            //         ),
            //       ),
            //     ),
            //   ),
            // ),

            // 🔥 LIVE BANNERS
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('banners')
                  .where('active', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox();
                }

                final banners = snapshot.data!.docs;

                return Column(
                  children: banners.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    return Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'] ?? "",
                            style: AppTheme.heading,
                          ),
                          const SizedBox(height: 10),
                          if (data['imageUrl'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                data['imageUrl'],
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // 🔥 QUICK ACTIONS
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Quick Actions",
                    style: AppTheme.subHeading,
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton.icon(
                    style: AppTheme.primaryButton,
                    onPressed: () {},
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Apply Membership"),
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton.icon(
                    style: AppTheme.accentButton,
                    onPressed: () {},
                    icon: const Icon(Icons.person),
                    label: const Text("View Profile"),
                  ),

                  const SizedBox(height: 20),

                  // 🔥 DELETE BUTTON (ADDED SAFELY)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: showDeleteDialog,
                    icon: const Icon(Icons.delete),
                    label: const Text("Delete Account"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}