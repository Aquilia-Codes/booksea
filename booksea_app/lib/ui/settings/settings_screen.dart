import 'package:booksea_app/models/user_model.dart';
import 'package:booksea_app/providers/auth_provider.dart';
import 'package:booksea_app/routes.dart';
import 'package:booksea_app/ui/performance/performance_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final currentUser = authProvider.currentUser;
    final photoUrl = authProvider.photoUrl;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/settings.png',
            fit: BoxFit.cover,
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.22,
            left: MediaQuery.of(context).size.width / 2 - 55,
            child: Container(
              padding: EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Center(
                child: CircleAvatar(
                  radius: 55,
                  backgroundImage: NetworkImage(
                      photoUrl ?? 'https://via.placeholder.com/150'),
                ),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.38,
                left: 20,
                right: 20),
            width: MediaQuery.of(context).size.width * 0.8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: StreamBuilder<UserModel>(
                      stream: user,
                      // Without this, a broadcast stream that already
                      // emitted once (during sign-in, before this screen
                      // ever mounted) leaves a fresh subscriber with no
                      // data at all - see AuthProvider.currentUser's doc
                      // comment.
                      initialData: currentUser,
                      builder: (context, snapshot) {
                        print(snapshot.data?.email);
                        print(snapshot.data?.nickname);
                        print(snapshot.data?.provision);
                        print(snapshot.data?.hasAccess);
                        print(snapshot.data?.isAdmin);
                        print(snapshot.data?.isOwner);
                        print(snapshot.data?.companyId);
                        print(snapshot.data?.boatIds);
                        print(snapshot.data?.uid);

                        if (snapshot.hasData) {
                          return Column(
                            children: [
                              Column(
                                children: [
                                  Text(
                                    'NICKNAME',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    snapshot.data!.nickname,
                                    style: TextStyle(
                                      fontSize: 24,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 15),
                                width: MediaQuery.of(context).size.width * 0.6,
                                child: Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        'PROVISION',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${snapshot.data!.provision}%',
                                        style: TextStyle(
                                          fontSize: 30,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => PerformanceScreen(
                                      isOwner: snapshot.data!.isOwner,
                                    ),
                                  ));
                                },
                                icon: Icon(Icons.bar_chart),
                                label: Text('Performance'),
                              ),
                              if (snapshot.data!.isOwner) ...[
                                SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context)
                                        .pushNamed(Routes.members);
                                  },
                                  icon: Icon(Icons.group),
                                  label: Text('Manage Members'),
                                ),
                              ],
                            ],
                          );
                        } else {
                          return Text(
                            '',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  SizedBox(height: 10),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.4),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      onPressed: () {
                        authProvider.signOut();
                      },
                      child: Text('Logout',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                  SizedBox(height: 10),
                  //TODO add form which company theyre from
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
