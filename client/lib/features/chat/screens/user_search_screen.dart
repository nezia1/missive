import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:missive/common/http.dart';
import 'package:missive/features/authentication/providers/auth_provider.dart';
import 'package:missive/features/encryption/providers/signal_provider.dart';
import 'package:provider/provider.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  List<String> _usernames = [];
  final TextEditingController _searchController = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _fetchUsers() async {
    if (_searchController.text.isEmpty) {
      return;
    }

    final response = await dio.get('/users',
        queryParameters: {'search': _searchController.text},
        options: Options(headers: {
          'Authorization':
              'Bearer ${await Provider.of<AuthProvider>(context, listen: false).accessToken}',
        }));

    setState(() {
      _usernames = List<String>.from(
          response.data['data']['users'].map((user) => user['name']).toList());
    });
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _usernames = [];
      });
      return;
    }

    _debouncer.run(
      () {
        _fetchUsers();
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _usernames.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_usernames[index]),
                  onTap: () async {
                    final accessToken =
                        await Provider.of<AuthProvider>(context, listen: false)
                            .accessToken;
                    if (!context.mounted) return;
                    await Provider.of<SignalProvider>(context, listen: false)
                        .buildSession(
                            name: _usernames[index], accessToken: accessToken!);

                    if (!context.mounted) return;
                    await context
                        .push('/conversations/${_usernames[index]}')
                        .then(
                          (value) => context.pop('/userSearch'),
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

class Debouncer {
  final int milliseconds;
  VoidCallback? action;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}
