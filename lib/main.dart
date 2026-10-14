import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? startupError;
  try {
    await Firebase.initializeApp(options: const FirebaseOptions(
      apiKey: 'AIzaSyBzrEVPxAlOkcWrbUk2VDujMY7P0BXJG_M',
      appId: '1:760036617793:android:9731134752d8ff02a960c0',
      messagingSenderId: '760036617793',
      projectId: 'legal-expart',
      storageBucket: 'legal-expart.firebasestorage.app',
    )).timeout(const Duration(seconds: 12));
  } catch (e) {
    startupError = e;
  }
  runApp(startupError == null
      ? const LegalExpartApp()
      : StartupFailureApp(error: startupError.toString()));
}

class StartupFailureApp extends StatelessWidget {
  final String error;
  const StartupFailureApp({super.key, required this.error});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Legal Expart',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff12345a))),
    home: Scaffold(
      backgroundColor: const Color(0xfff5f8fc),
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 150, child: SvgPicture.asset('assets/legal_expart_logo.svg')),
          const SizedBox(height: 18),
          const Text('Legal Expart', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xff12345a))),
          const SizedBox(height: 12),
          const Text('App could not connect to Firebase. Please check your app configuration and internet connection.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          const Text('ऐप Firebase से कनेक्ट नहीं हो पाया। इंटरनेट और Firebase configuration जाँचें।',
            textAlign: TextAlign.center),
          const SizedBox(height: 16),
          SelectableText(error, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
        ]),
      ))),
    ),
  );
}

String tr(bool hi, String en, String hn) => hi ? hn : en;

class LegalExpartApp extends StatefulWidget {
  const LegalExpartApp({super.key});
  @override
  State<LegalExpartApp> createState() => _LegalExpartAppState();
}
class _LegalExpartAppState extends State<LegalExpartApp> {
  bool hindi = true;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Legal Expart',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff12345a)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff5f8fc),
    ),
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        if (user == null) {
          return LoginPage(hindi: hindi, toggle: () => setState(() => hindi = !hindi));
        }
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (roleSnapshot.hasError) {
              return const Scaffold(body: Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not verify account role. Please check internet and Firestore rules.'),
              )));
            }
            final profile = roleSnapshot.data?.data();
            final role = profile?['role']?.toString().trim().toLowerCase();
            // Never silently treat a missing profile as a customer/admin.
            // Show the exact UID and detected role to help correct Firestore setup.
            if (Platform.isWindows && role != 'admin') {
              final detail = profile == null
                  ? 'Firestore में lowercase users collection के अंदर इस UID का document नहीं मिला।'
                  : 'इस UID का role = "${role ?? 'missing'}" मिला; role की value admin होनी चाहिए।';
              return RoleAccessDeniedPage(
                hindi: hindi,
                message: 'यह Windows Admin App है।\n$detail\nUID: ${user.uid}',
              );
            }
            if (!Platform.isWindows && role == 'admin') {
              return RoleAccessDeniedPage(
                hindi: hindi,
                message: 'Admin account केवल Windows Admin App में इस्तेमाल करें।',
              );
            }
            return Platform.isWindows
              ? const AdminDashboardPage()
              : DashboardPage(hindi: hindi, toggle: () => setState(() => hindi = !hindi));
          },
        );
      },
    ),
  );
}

class RoleAccessDeniedPage extends StatelessWidget {
  final bool hindi;
  final String message;
  const RoleAccessDeniedPage({super.key, required this.hindi, required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async => FirebaseAuth.instance.signOut(),
              child: Text(tr(hindi, 'Back to Login', 'लॉगिन पर वापस जाएँ')),
            ),
          ],
        ),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  final bool hindi;
  final VoidCallback toggle;
  const LoginPage({super.key, required this.hindi, required this.toggle});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool admin = false, busy = false;
  String error = '';

  Future<void> signIn() async {
    setState(() { busy = true; error = ''; });
    try {
      final c = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(), password: password.text);
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(c.user!.uid).get();
      final role = userDoc.data()?['role'] ?? 'customer';
      final allowed = Platform.isWindows ? role == 'admin' : role != 'admin';
      if (!allowed) {
        // Keep the session so the app shows the role mismatch instead of blinking to login.
        throw Exception(Platform.isWindows
            ? tr(widget.hindi, 'Access denied: account role is "' + role.toString() + '". Firestore document users/' + c.user!.uid + ' must have role = "admin".', 'प्रवेश अस्वीकृत: इस account का role "' + role.toString() + '" है। Firestore document users/' + c.user!.uid + ' में role = "admin" होना चाहिए।')
            : tr(widget.hindi, 'Admin accounts can only use the Windows Admin app.', 'Admin account केवल Windows Admin App में इस्तेमाल करें।'));
      }
    } on FirebaseAuthException catch (e) {
      error = e.message ?? tr(widget.hindi, 'Login failed.', 'लॉगिन नहीं हो सका।');
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> register() async {
    setState(() { busy = true; error = ''; });
    try {
      final c = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(), password: password.text);
      await FirebaseFirestore.instance.collection('users').doc(c.user!.uid).set({
        'email': email.text.trim(), 'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (admin) {
        await FirebaseAuth.instance.signOut();
        throw Exception(tr(widget.hindi,
          'Admin accounts must be created by a trusted administrator.',
          'Admin अकाउंट केवल अधिकृत एडमिन बना सकता है।'));
      }
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Registration failed';
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(actions: [
      TextButton(onPressed: widget.toggle, child: Text(widget.hindi ? 'English' : 'हिंदी'))
    ]),
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 112, child: SvgPicture.asset('assets/legal_expart_logo.svg', fit: BoxFit.contain)),
          const SizedBox(height: 8),
          const Text('Legal Expart', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xff12345a))),
          Text(tr(widget.hindi, 'Your Legal Partner, Always', 'आपका भरोसेमंद कानूनी साथी'),
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey)),
          const SizedBox(height: 28),
          Text(tr(widget.hindi, 'Welcome back', 'आपका स्वागत है'),
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (Platform.isWindows)
            Text(
              tr(widget.hindi, 'Windows Admin Login', 'Windows Admin लॉगिन'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xff12345a)),
            )
          else
            Text(
              tr(widget.hindi, 'Customer Login', 'ग्राहक लॉगिन'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xff12345a)),
            ),
          const SizedBox(height: 16),
          TextField(controller: email, keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: tr(widget.hindi, 'Email', 'ईमेल'),
              prefixIcon: const Icon(Icons.email_outlined), border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true,
            decoration: InputDecoration(labelText: tr(widget.hindi, 'Password', 'पासवर्ड'),
              prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder())),
          if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(error, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 18),
          FilledButton(onPressed: busy ? null : signIn,
            child: Padding(padding: const EdgeInsets.all(12), child: Text(
              busy ? tr(widget.hindi, 'Please wait…', 'कृपया प्रतीक्षा करें…') : tr(widget.hindi, 'Login', 'लॉगिन')))),
          if (!Platform.isWindows) OutlinedButton(onPressed: busy ? null : register,
            child: Text(tr(widget.hindi, 'Create customer account', 'ग्राहक अकाउंट बनाएँ'))),
          const SizedBox(height: 14),
          Text(tr(widget.hindi,
            'GST, MSME, FSSAI, trademark, digital signature and legal consultation.',
            'GST, MSME, FSSAI, ट्रेडमार्क, डिजिटल सिग्नेचर और कानूनी सलाह।'),
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey)),
        ]),
      ),
    )),
  );
}


class MyProfilePage extends StatelessWidget {
  final bool hindi;
  const MyProfilePage({super.key, required this.hindi});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName?.trim().isNotEmpty ?? false) ? user!.displayName! : (user?.email?.split('@').first ?? tr(hindi, 'Customer', 'ग्राहक'));
    return Scaffold(
      appBar: AppBar(title: Text(tr(hindi, 'My Profile', 'मेरी प्रोफ़ाइल'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xff12345a), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            const CircleAvatar(radius: 32, backgroundColor: Colors.white, child: Icon(Icons.person, size: 38, color: Color(0xff12345a))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(user?.email ?? '', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(tr(hindi, 'Customer Account', 'ग्राहक अकाउंट'), style: const TextStyle(color: Color(0xffffd36b), fontSize: 12)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),
        Text(tr(hindi, 'Your Activity', 'आपकी गतिविधियाँ'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _ProfileAction(icon: Icons.history, title: tr(hindi, 'Booking History', 'बुकिंग हिस्ट्री'),
          subtitle: tr(hindi, 'View your service requests and status', 'अपनी सर्विस रिक्वेस्ट और स्टेटस देखें'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestHistoryPage(hindi: hindi, consultationsOnly: false)))),
        _ProfileAction(icon: Icons.gavel, title: tr(hindi, 'Consultation History', 'कंसल्टिंग हिस्ट्री'),
          subtitle: tr(hindi, 'Your legal consultation requests', 'आपकी कानूनी सलाह की रिक्वेस्ट'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestHistoryPage(hindi: hindi, consultationsOnly: true)))),
        _ProfileAction(icon: Icons.folder_open_outlined, title: tr(hindi, 'Documents', 'दस्तावेज़'),
          subtitle: tr(hindi, 'Documents related to your requests', 'आपकी रिक्वेस्ट से जुड़े दस्तावेज़'),
          onTap: () => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
            title: Text(tr(hindi, 'Documents', 'दस्तावेज़')),
            content: Text(tr(hindi, 'Document upload/download needs storage configuration.', 'दस्तावेज़ अपलोड/डाउनलोड के लिए स्टोरेज कॉन्फ़िगरेशन ज़रूरी है।')),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ))),
        _ProfileAction(icon: Icons.person_outline, title: tr(hindi, 'Account Details', 'अकाउंट विवरण'),
          subtitle: user?.email ?? '',
          onTap: () => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
            title: Text(tr(hindi, 'Account Details', 'अकाउंट विवरण')),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(hindi, 'Name', 'नाम') + ': ' + name),
              const SizedBox(height: 8),
              SelectableText(user?.email ?? ''),
            ]),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(hindi, 'Close', 'बंद करें')))],
          ))),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        }, icon: const Icon(Icons.logout), label: Text(tr(hindi, 'Logout', 'लॉग आउट'))),
      ]),
    );
  }
}
class _ProfileAction extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  const _ProfileAction({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 5),
    child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xffeaf1fb), child: Icon(icon, color: const Color(0xff12345a))),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right), onTap: onTap,
    ),
  );
}
class RequestHistoryPage extends StatelessWidget {
  final bool hindi; final bool consultationsOnly;
  const RequestHistoryPage({super.key, required this.hindi, required this.consultationsOnly});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text(consultationsOnly ? tr(hindi, 'Consultation History', 'कंसल्टिंग हिस्ट्री') : tr(hindi, 'Booking History', 'बुकिंग हिस्ट्री'))),
      body: user == null
        ? Center(child: Text(tr(hindi, 'Please log in again.', 'कृपया दोबारा लॉगिन करें।')))
        : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('serviceRequests').where('uid', isEqualTo: user.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20),
              child: Text(tr(hindi, 'Could not load history. Check Firestore rules and connection.', 'हिस्ट्री लोड नहीं हो सकी। Firestore rules और इंटरनेट कनेक्शन जाँचें।'))));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs.where((doc) {
              final service = (doc.data()['service'] ?? '').toString().toLowerCase();
              final isConsultation = service.contains('consultation') || service.contains('सलाह');
              return consultationsOnly ? isConsultation : true;
            }).toList()..sort((a, b) {
              final av = a.data()['createdAt']; final bv = b.data()['createdAt'];
              final am = av is Timestamp ? av.millisecondsSinceEpoch : 0;
              final bm = bv is Timestamp ? bv.millisecondsSinceEpoch : 0;
              return bm.compareTo(am);
            });
            if (docs.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(consultationsOnly ? Icons.gavel : Icons.history, size: 56, color: Colors.blueGrey.shade300),
                const SizedBox(height: 12),
                Text(consultationsOnly ? tr(hindi, 'No consultation history yet.', 'अभी कोई कंसल्टिंग हिस्ट्री नहीं है।') : tr(hindi, 'No bookings yet.', 'अभी कोई बुकिंग नहीं है।'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(tr(hindi, 'Your submitted requests will appear here.', 'आपकी भेजी गई रिक्वेस्ट यहाँ दिखाई देंगी।'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey)),
              ])));
            return ListView.builder(padding: const EdgeInsets.all(12), itemCount: docs.length, itemBuilder: (context, index) {
              final data = docs[index].data();
              final status = (data['status'] ?? 'Pending').toString();
              final note = (data['note'] ?? '').toString();
              final createdAt = data['createdAt'];
              final dateText = createdAt is Timestamp ? MaterialLocalizations.of(context).formatShortDate(createdAt.toDate()) : tr(hindi, 'Date pending', 'तारीख उपलब्ध नहीं');
              final dateLabel = tr(hindi, 'Date', 'तारीख');
              final noteText = note.isEmpty ? '' : '\n' + note;
              return Card(margin: const EdgeInsets.symmetric(vertical: 6), child: ListTile(
                leading: CircleAvatar(backgroundColor: const Color(0xffeaf1fb), child: Icon(consultationsOnly ? Icons.gavel : Icons.assignment_outlined, color: const Color(0xff12345a))),
                title: Text((data['service'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(dateLabel + ': ' + dateText + noteText)),
                trailing: Container(constraints: const BoxConstraints(maxWidth: 100), padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(color: status == 'Completed' ? const Color(0xffd9f4df) : const Color(0xfffff0cc), borderRadius: BorderRadius.circular(20)),
                  child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: status == 'Completed' ? const Color(0xff18763a) : const Color(0xff805800))),
                ),
              ));
            });
          },
        ),
    );
  }
}


class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  static const navy = Color(0xff12345a);
  static const statuses = ['Pending', 'In Progress', 'Completed', 'Cancelled'];
  int selected = 0;
  static const sections = [
    ('Dashboard', Icons.dashboard_outlined),
    ('Service Requests', Icons.assignment_outlined),
    ('Add Service', Icons.add_business_outlined),
    ('Add Offers', Icons.local_offer_outlined),
    ('Customer Information', Icons.people_outline),
  ];

  Future<void> _setStatus(BuildContext context, String id, String status) async {
    try {
      await FirebaseFirestore.instance.collection('serviceRequests').doc(id).update({
        'status': status, 'updatedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated: $status')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update status: $e')));
    }
  }

  Future<void> _addCatalogItem({required bool offer}) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final price = TextEditingController();
    final discount = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(offer ? 'Add Offer' : 'Add Service'),
      content: SizedBox(width: 420, child: Form(key: formKey, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Name / Title'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
          TextFormField(controller: price, decoration: const InputDecoration(labelText: 'Price (₹)', prefixText: '₹ '), keyboardType: TextInputType.number, validator: offer ? null : (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          if (offer) TextFormField(controller: discount, decoration: const InputDecoration(labelText: 'Discount / Offer details')),
        ],
      )))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Save')),
      ],
    ));
    if (saved == true) {
      try {
        final collection = FirebaseFirestore.instance.collection(offer ? 'offers' : 'services');
        await collection.add({
          'name': name.text.trim(),
          'title': name.text.trim(),
          'description': description.text.trim(),
          if (price.text.trim().isNotEmpty) 'price': price.text.trim(),
          if (discount.text.trim().isNotEmpty) 'discount': discount.text.trim(),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(offer ? 'Offer added successfully.' : 'Service added successfully.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed. Update Firestore Rules for ${offer ? 'offers' : 'services'} collection. Details: $e')));
      }
    }
    name.dispose(); description.dispose(); price.dispose(); discount.dispose();
  }

  Widget _metric(String title, int value, IconData icon) => _AdminMetric(title: title, value: '$value', icon: icon);

  Widget _dashboard() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('serviceRequests').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text('Unable to load requests: ${snapshot.error}'));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final docs = snapshot.data!.docs;
      final pending = docs.where((d) => (d.data()['status'] ?? 'Pending') == 'Pending').length;
      final active = docs.where((d) => (d.data()['status'] ?? '') == 'In Progress').length;
      final completed = docs.where((d) => (d.data()['status'] ?? '') == 'Completed').length;
      return ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Admin Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy)),
        const SizedBox(height: 6),
        const Text('Manage services, offers, customer information and consultation bookings.'),
        const SizedBox(height: 18),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _metric('Total Requests', docs.length, Icons.inbox_outlined),
          _metric('Pending', pending, Icons.pending_actions),
          _metric('In Progress', active, Icons.autorenew),
          _metric('Completed', completed, Icons.task_alt),
        ]),
        const SizedBox(height: 22),
        const Text('Quick actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          FilledButton.icon(onPressed: () => setState(() => selected = 2), icon: const Icon(Icons.add), label: const Text('Add Service')),
          FilledButton.icon(onPressed: () => setState(() => selected = 3), icon: const Icon(Icons.local_offer), label: const Text('Add Offers')),
          OutlinedButton.icon(onPressed: () => setState(() => selected = 4), icon: const Icon(Icons.people), label: const Text('Customer Information')),
        ]),
        const SizedBox(height: 20),
        const Text('Recent Customer Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...docs.take(5).map((doc) {
          final d = doc.data();
          return Card(child: ListTile(
            leading: const Icon(Icons.assignment_outlined, color: navy),
            title: Text((d['service'] ?? 'Service request').toString()),
            subtitle: Text('${d['email'] ?? d['customerEmail'] ?? ''}\n${d['note'] ?? d['message'] ?? ''}'),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              initialValue: statuses.contains((d['status'] ?? 'Pending').toString()) ? (d['status'] ?? 'Pending').toString() : 'Pending',
              onSelected: (v) => _setStatus(context, doc.id, v),
              itemBuilder: (_) => statuses.map((v) => PopupMenuItem(value: v, child: Text(v))).toList(),
              child: Text((d['status'] ?? 'Pending').toString()),
            ),
          ));
        }),
      ]);
    },
  );

  Widget _requests() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('serviceRequests').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text('Could not load requests: ${snapshot.error}'));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final docs = snapshot.data!.docs.toList()..sort((a, b) {
        final av = a.data()['createdAt']; final bv = b.data()['createdAt'];
        return (bv is Timestamp ? bv.millisecondsSinceEpoch : 0).compareTo(av is Timestamp ? av.millisecondsSinceEpoch : 0);
      });
      return ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Customer Requests', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (docs.isEmpty) const Text('No service requests found.'),
        ...docs.map((doc) {
          final d = doc.data(); final status = (d['status'] ?? 'Pending').toString();
          return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.assignment_outlined, color: navy),
              const SizedBox(width: 10),
              Expanded(child: Text((d['service'] ?? 'Service request').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              PopupMenuButton<String>(onSelected: (v) => _setStatus(context, doc.id, v),
                itemBuilder: (_) => statuses.map((v) => PopupMenuItem(value: v, child: Text(v))).toList(),
                child: Chip(label: Text(status))),
            ]),
            Text('Customer: ${d['email'] ?? d['customerEmail'] ?? 'Unknown'}'),
            if ((d['note'] ?? d['message'] ?? '').toString().isNotEmpty) Text('Details: ${d['note'] ?? d['message']}'),
            if (d['uid'] != null) SelectableText('Customer UID: ${d['uid']}'),
          ])));
        }),
      ]);
    },
  );

  Widget _catalog({required bool offer}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8), child: Row(children: [
      Expanded(child: Text(offer ? 'Offers' : 'Services', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
      FilledButton.icon(onPressed: () => _addCatalogItem(offer: offer), icon: const Icon(Icons.add), label: Text(offer ? 'Add Offer' : 'Add Service')),
    ])),
    Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(offer ? 'offers' : 'services').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Could not load ${offer ? 'offers' : 'services'}. Check Firestore Rules.\n${snapshot.error}')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return Center(child: Text('No ${offer ? 'offers' : 'services'} yet. Use the button above to add one.'));
        return ListView(padding: const EdgeInsets.all(20), children: snapshot.data!.docs.map((doc) {
          final d = doc.data();
          return Card(child: ListTile(
            leading: Icon(offer ? Icons.local_offer_outlined : Icons.miscellaneous_services, color: navy),
            title: Text((d['name'] ?? d['title'] ?? 'Untitled').toString()),
            subtitle: Text('${d['description'] ?? ''}${d['price'] != null ? '\nPrice: ₹${d['price']}' : ''}${d['discount'] != null ? '\nOffer: ${d['discount']}' : ''}'),
            isThreeLine: true,
            trailing: IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () async {
              final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Delete item?'),
                content: const Text('This cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                ],
              ));
              if (yes == true) {
                try { await doc.reference.delete(); }
                catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'))); }
              }
            }),
          ));
        }).toList());
      },
    )),
  ]);

  Widget _customers() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('users').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Could not load customers. Check Firestore Rules.\n${snapshot.error}')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final docs = snapshot.data!.docs.where((d) => d.data()['role'] == 'customer').toList();
      return ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Customer Information', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text('Total customers: ${docs.length}'),
        const SizedBox(height: 8),
        if (docs.isEmpty) const Text('No customer profiles found in users collection.'),
        ...docs.map((doc) {
          final d = doc.data();
          return Card(child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text((d['name'] ?? 'Customer').toString()),
            subtitle: Text('${d['email'] ?? ''}\nUID: ${doc.id}'),
            isThreeLine: true,
          ));
        }),
      ]);
    },
  );

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(backgroundColor: navy, foregroundColor: Colors.white,
        title: const Row(children: [Icon(Icons.admin_panel_settings, size: 28), SizedBox(width: 10), Text('Legal Expart | Admin')]),
        actions: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Center(child: Text(user?.email ?? 'Admin', style: const TextStyle(fontSize: 12)))),
          IconButton(tooltip: 'Logout', onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
        ]),
      body: Row(children: [
        NavigationRail(
          selectedIndex: selected,
          onDestinationSelected: (v) => setState(() => selected = v),
          labelType: NavigationRailLabelType.all,
          destinations: sections.map((s) => NavigationRailDestination(icon: Icon(s.$2), label: Text(s.$1))).toList(),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: IndexedStack(index: selected, children: [
          _dashboard(), _requests(), _catalog(offer: false), _catalog(offer: true), _customers(),
        ])),
      ]),
    );
  }
}

class _AdminMetric extends StatelessWidget {
  final String title; final String value; final IconData icon;
  const _AdminMetric({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    width: 205, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xffe0e8f2))),
    child: Row(children: [
      CircleAvatar(backgroundColor: const Color(0xffeaf1fb), child: Icon(icon, color: AdminDashboardPage.navy)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AdminDashboardPage.navy)),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
      ])),
    ]),
  );
}

class DashboardPage extends StatelessWidget {
  final bool hindi;
  final VoidCallback toggle;
  const DashboardPage({super.key, required this.hindi, required this.toggle});

  static const services = [
    ('GST Registration', 'GST रजिस्ट्रेशन', '₹599', Icons.receipt_long),
    ('MSME / Udyam', 'MSME / उद्यम', '₹699', Icons.storefront),
    ('Food License (FSSAI)', 'फूड लाइसेंस (FSSAI)', '₹799', Icons.restaurant),
    ('Digital Signature', 'डिजिटल सिग्नेचर', '₹999', Icons.verified_user),
    ('Trademark Registration', 'ट्रेडमार्क रजिस्ट्रेशन', '₹2,999', Icons.shield_outlined),
    ('Legal Consultation', 'कानूनी सलाह', '₹499', Icons.gavel),
  ];

  Future<bool> isAdmin() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data()?['role'] == 'admin';
  }

  Future<void> requestService(BuildContext context, String service) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr(hindi, 'Request service', 'सर्विस रिक्वेस्ट')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(service), const SizedBox(height: 12),
        TextField(controller: note, maxLines: 3,
          decoration: InputDecoration(hintText: tr(hindi, 'Describe your requirement', 'अपनी आवश्यकता लिखें'),
            border: const OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(hindi, 'Cancel', 'रद्द करें'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(hindi, 'Submit', 'जमा करें'))),
      ],
    ));
    if (ok == true) {
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('serviceRequests').add({
        'uid': user.uid, 'email': user.email, 'service': service,
        'note': note.text.trim(), 'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(hindi, 'Request submitted successfully', 'आपकी रिक्वेस्ट जमा हो गई है'))));
    }
    note.dispose();
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton(
          tooltip: tr(hindi, 'My Profile', 'मेरी प्रोफ़ाइल'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MyProfilePage(hindi: hindi))),
          icon: const CircleAvatar(backgroundColor: Color(0xffeaf1fb),
            child: Icon(Icons.person_outline, color: Color(0xff12345a))),
        ),
      ),
      title: const Text('Legal Expart', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        TextButton(onPressed: toggle, child: Text(hindi ? 'English' : 'हिंदी')),
        IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
      ],
    ),
    body: FutureBuilder<bool>(future: isAdmin(), builder: (context, roleSnap) {
      final admin = roleSnap.data == true;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: const Color(0xff12345a), borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.balance, color: Color(0xffffd36b), size: 40),
            const SizedBox(height: 10),
            Text(tr(hindi, admin ? 'Admin Dashboard' : 'Your Legal Needs, Our Priority',
              admin ? 'एडमिन डैशबोर्ड' : 'आपकी कानूनी ज़रूरत, हमारी प्राथमिकता'),
              style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(tr(hindi, 'Expert support for individuals and businesses.',
              'व्यक्तियों और व्यवसायों के लिए विशेषज्ञ सहायता।'), style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 22),
        Text(tr(hindi, admin ? 'All service requests' : 'Our Services',
          admin ? 'सभी सर्विस रिक्वेस्ट' : 'हमारी सेवाएँ'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (admin)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('serviceRequests')
              .orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return Text('Error: ${snap.error}');
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              if (snap.data!.docs.isEmpty) return Padding(padding: const EdgeInsets.all(20),
                child: Text(tr(hindi, 'No requests yet.', 'अभी कोई रिक्वेस्ट नहीं है।')));
              return Column(children: snap.data!.docs.map((d) {
                final data = d.data();
                final status = data['status'] ?? 'Pending';
                return Card(child: ListTile(
                  leading: const Icon(Icons.assignment, color: Color(0xff1268df)),
                  title: Text(data['service'] ?? ''),
                  subtitle: Text('${data['email'] ?? ''}\n${data['note'] ?? ''}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => d.reference.update({'status': v}),
                    itemBuilder: (_) => ['Pending', 'In Progress', 'Completed']
                      .map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
                    child: Text(status),
                  ),
                ));
              }).toList());
            },
          )
        else
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, childAspectRatio: .94, crossAxisSpacing: 12, mainAxisSpacing: 12,
            children: services.map((s) => Card(clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: () => requestService(context, s.$1),
                child: Padding(padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(backgroundColor: const Color(0xffeaf1fb), child: Icon(s.$4, color: const Color(0xff12345a))),
                    const Spacer(),
                    Text(tr(hindi, s.$1, s.$2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(s.$3, style: const TextStyle(color: Color(0xff1268df), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(tr(hindi, 'Request service →', 'सर्विस लें →'),
                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                  ]),
                ),
              ),
            )).toList()),
        const SizedBox(height: 18),
        Card(child: ListTile(leading: const Icon(Icons.support_agent),
          title: Text(tr(hindi, 'Need legal assistance?', 'कानूनी सहायता चाहिए?')),
          subtitle: Text(tr(hindi, 'Submit a request and our team will follow up.',
            'रिक्वेस्ट भेजें, हमारी टीम आपसे संपर्क करेगी।')))),
      ]);
    }),
  );
}
