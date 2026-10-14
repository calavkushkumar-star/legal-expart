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
        return snapshot.data == null
          ? LoginPage(hindi: hindi, toggle: () => setState(() => hindi = !hindi))
          : DashboardPage(hindi: hindi, toggle: () => setState(() => hindi = !hindi));
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
    appBar: AppBar(title: const Text('Legal Expart', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        TextButton(onPressed: toggle, child: Text(hindi ? 'English' : 'हिंदी')),
        IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
      ]),
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
