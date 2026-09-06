import 'package:booksea_app/models/boat_model.dart';
import 'package:booksea_app/models/member_model.dart';
import 'package:booksea_app/providers/auth_provider.dart';
import 'package:booksea_app/services/api_client.dart';
import 'package:booksea_app/services/api_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Owner-only screen (see backend/src/routes/companies.ts GET/PATCH
// /companies/:id/members). A "pending" member is just a user who joined
// with the company code (POST /me/company) but hasn't been granted access
// yet - there's no separate invite system, self-joining with the code is
// the request, and this screen is where an owner reviews it.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  late final ApiDatabase _db;
  late final String _companyId;
  late final String? _myUserId;
  Future<List<MemberModel>>? _membersFuture;
  List<BoatModel> _boats = [];

  @override
  void initState() {
    super.initState();
    _db = Provider.of<ApiDatabase>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _companyId = authProvider.companyId!;
    _myUserId = authProvider.userId;
    _loadBoats();
    _reload();
  }

  Future<void> _loadBoats() async {
    final boats = await _db.getCompanyBoats(_companyId);
    if (mounted) setState(() => _boats = boats);
  }

  void _reload() {
    setState(() {
      _membersFuture = _db.getCompanyMembers(_companyId);
    });
  }

  Future<void> _editMember(MemberModel member) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MemberEditSheet(
        member: member,
        boats: _boats,
        companyId: _companyId,
        db: _db,
        isSelf: member.id == _myUserId,
      ),
    );
    if (updated == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: FutureBuilder<List<MemberModel>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final members = snapshot.data ?? [];
          final pending = members.where((m) => !m.hasAccess).toList();
          final active = members.where((m) => m.hasAccess).toList();
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              children: [
                if (pending.isEmpty && active.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No members yet.')),
                  ),
                if (pending.isNotEmpty) ...[
                  _SectionHeader('Pending approval (${pending.length})'),
                  for (final m in pending)
                    _MemberTile(
                      member: m,
                      isSelf: m.id == _myUserId,
                      onTap: () => _editMember(m),
                    ),
                ],
                if (active.isNotEmpty) ...[
                  _SectionHeader('Active (${active.length})'),
                  for (final m in active)
                    _MemberTile(
                      member: m,
                      isSelf: m.id == _myUserId,
                      onTap: () => _editMember(m),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isSelf,
    required this.onTap,
  });

  final MemberModel member;
  final bool isSelf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final roleLabels = [
      if (member.isOwner) 'Owner',
      if (member.isAdmin) 'Admin',
    ];
    return ListTile(
      onTap: onTap,
      title: Text(
        member.nickname.isNotEmpty ? member.nickname : member.email,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        [
          member.email,
          if (roleLabels.isNotEmpty) roleLabels.join(', '),
          if (member.boatNames.isNotEmpty) member.boatNames.join(', '),
          '${member.provision}% provision',
        ].join(' · '),
      ),
      trailing: !member.hasAccess
          ? Chip(
              label: const Text('Pending'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            )
          : isSelf
              ? const Chip(label: Text('You'))
              : null,
    );
  }
}

class _MemberEditSheet extends StatefulWidget {
  const _MemberEditSheet({
    required this.member,
    required this.boats,
    required this.companyId,
    required this.db,
    required this.isSelf,
  });

  final MemberModel member;
  final List<BoatModel> boats;
  final String companyId;
  final ApiDatabase db;
  final bool isSelf;

  @override
  State<_MemberEditSheet> createState() => _MemberEditSheetState();
}

class _MemberEditSheetState extends State<_MemberEditSheet> {
  late bool _hasAccess;
  late bool _isAdmin;
  late bool _isOwner;
  late final TextEditingController _provisionController;
  late Set<String> _selectedBoats;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hasAccess = widget.member.hasAccess;
    _isAdmin = widget.member.isAdmin;
    _isOwner = widget.member.isOwner;
    _provisionController =
        TextEditingController(text: widget.member.provision.toString());
    _selectedBoats = widget.member.boatNames.toSet();
  }

  @override
  void dispose() {
    _provisionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.db.updateMember(
        widget.companyId,
        widget.member.id,
        hasAccess: _hasAccess,
        isAdmin: _isAdmin,
        isOwner: _isOwner,
        provision: int.tryParse(_provisionController.text) ?? 0,
        boatNames: _selectedBoats.toList(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.member.nickname.isNotEmpty
                  ? widget.member.nickname
                  : widget.member.email,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(widget.member.email,
                style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Has access'),
              value: _hasAccess,
              onChanged: (v) => setState(() => _hasAccess = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Admin'),
              value: _isAdmin,
              onChanged: (v) => setState(() => _isAdmin = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Owner'),
              subtitle: widget.isSelf
                  ? const Text(
                      "Removing your own owner status is blocked if you're the last owner")
                  : null,
              value: _isOwner,
              onChanged: (v) => setState(() => _isOwner = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _provisionController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Provision %',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.boats.isNotEmpty) ...[
              Text('Boat access',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary)),
              Wrap(
                spacing: 8,
                children: widget.boats.map((boat) {
                  final selected = _selectedBoats.contains(boat.name);
                  return FilterChip(
                    label: Text(boat.name),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedBoats.add(boat.name);
                      } else {
                        _selectedBoats.remove(boat.name);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
