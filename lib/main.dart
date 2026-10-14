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
            final role = roleSnapshot.data?.data()?['role'] ?? 'customer';
            return role == 'admin'
              ? const AdminDashboardPage()
              : DashboardPage(hindi: hindi, toggle: () => setState(() => hindi = !hindi));
          },
        );
      },
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
      final doc = await FirebaseFirestore.instance.collection('users').doc(c.user!.uid).get();
      final role = doc.data()?['role'] ?? 'customer';
      if ((admin && role != 'admin') || (!admin && role != 'customer')) {
        await FirebaseAuth.instance.signOut();
        throw Exception(tr(widget.hindi, 'This account does not have the selected role.',
          'इस खाते के पास चुनी गई भूमिका की अनुमति नहीं है।'));
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
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(tr(widget.hindi, 'Customer', 'ग्राहक')),
                icon: const Icon(Icons.person_outline)),
              ButtonSegment(value: true, label: Text(tr(widget.hindi, 'Admin', 'एडमिन')),
                icon: const Icon(Icons.admin_panel_settings_outlined)),
            ],
            selected: {admin}, onSelectionChanged: (s) => setState(() => admin = s.first)),
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
          if (!admin) OutlinedButton(onPressed: busy ? null : register,
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


class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});
  static const navy = Color(0xff12345a);
  static const statuses = ['Pending', 'In Progress', 'Completed', 'Cancelled'];

  Future<void> _setStatus(BuildContext context, String id, String status) async {
    try {
      await FirebaseFirestore.instance.collection('serviceRequests').doc(id).update({
        'status': status, 'updatedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated: $status')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not update status. Check admin role and Firestore rules.')));
    }
  }

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
      body: LayoutBuilder(builder: (context, constraints) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Admin Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 6),
          const Text('Manage customer service requests and consultation bookings.'),
          const SizedBox(height: 18),
          Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('serviceRequests').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Unable to load requests. Verify the admin role and Firestore Security Rules.'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs.toList()..sort((a, b) {
                final av = a.data()['createdAt']; final bv = b.data()['createdAt'];
                final am = av is Timestamp ? av.millisecondsSinceEpoch : 0;
                final bm = bv is Timestamp ? bv.millisecondsSinceEpoch : 0;
                return bm.compareTo(am);
              });
              final pending = docs.where((d) => (d.data()['status'] ?? 'Pending') == 'Pending').length;
              final active = docs.where((d) => (d.data()['status'] ?? '') == 'In Progress').length;
              final completed = docs.where((d) => (d.data()['status'] ?? '') == 'Completed').length;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _AdminMetric(title: 'Total Requests', value: '${docs.length}', icon: Icons.inbox_outlined),
                  _AdminMetric(title: 'Pending', value: '$pending', icon: Icons.pending_actions),
                  _AdminMetric(title: 'In Progress', value: '$active', icon: Icons.autorenew),
                  _AdminMetric(title: 'Completed', value: '$completed', icon: Icons.task_alt),
                ]),
                const SizedBox(height: 18),
                const Text('Customer Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(child: docs.isEmpty
                  ? const Center(child: Text('No service requests have been submitted yet.'))
                  : ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index]; final data = doc.data();
                      final status = (data['status'] ?? 'Pending').toString();
                      final created = data['createdAt'];
                      final dateText = created is Timestamp ? MaterialLocalizations.of(context).formatShortDate(created.toDate()) : 'Date unavailable';
                      final service = (data['service'] ?? 'Service request').toString();
                      final email = (data['email'] ?? data['customerEmail'] ?? '').toString();
                      final note = (data['note'] ?? data['message'] ?? '').toString();
                      return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const CircleAvatar(backgroundColor: Color(0xffeaf1fb), child: Icon(Icons.assignment_outlined, color: navy)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(service, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(dateText, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                            ])),
                            PopupMenuButton<String>(
                              tooltip: 'Update status',
                              initialValue: statuses.contains(status) ? status : 'Pending',
                              onSelected: (v) => _setStatus(context, doc.id, v),
                              itemBuilder: (_) => statuses.map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
                              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(color: status == 'Completed' ? const Color(0xffd9f4df) : const Color(0xfffff0cc), borderRadius: BorderRadius.circular(18)),
                                child: Text(status, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                            ),
                          ]),
                          if (email.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Customer: $email')),
                          if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Details: $note')),
                          if (data['uid'] != null) Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text('Customer UID: ' + data['uid'].toString(),
                              style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
                          ),
                        ],
                      )));
                    },
                  )),
              ]);
            },
          )),
        ]),
      )),
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
