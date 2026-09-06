import 'package:booksea_app/models/performance_model.dart';
import 'package:booksea_app/providers/auth_provider.dart';
import 'package:booksea_app/services/api_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// Reachable by any user (own stats); an owner additionally sees every
// booker's numbers for the selected boat - see backend/src/routes/boats.ts
// GET /boats/:id/performance and .../performance/team.
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key, required this.isOwner});

  final bool isOwner;

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  late final ApiDatabase _db;
  late String _boatId;
  late List<String> _boatIds;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  Future<PerformanceModel>? _myFuture;
  Future<List<TeamPerformanceEntry>>? _teamFuture;

  @override
  void initState() {
    super.initState();
    _db = Provider.of<ApiDatabase>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _boatIds = authProvider.boatIds;
    _boatId = _boatIds.first;
    _reload();
  }

  void _reload() {
    // Include the whole end day, matching the pattern used elsewhere
    // (home.dart's day-range streams) - a bare DateTime for "today" has a
    // midnight time component, which would exclude tours later that day.
    final rangeEnd =
        DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
    setState(() {
      _myFuture = _db.getMyPerformance(_boatId, _startDate, rangeEnd);
      _teamFuture = widget.isOwner
          ? _db.getTeamPerformance(_boatId, _startDate, rangeEnd)
          : null;
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
      _reload();
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_boatIds.length > 1)
            DropdownButtonFormField<String>(
              initialValue: _boatId,
              decoration: const InputDecoration(labelText: 'Boat'),
              items: _boatIds
                  .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _boatId = value);
                _reload();
              },
            ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _pickStartDate,
                  child: Text('From: ${dateFormat.format(_startDate)}'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _pickEndDate,
                  child: Text('To: ${dateFormat.format(_endDate)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<PerformanceModel>(
            future: _myFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              final performance = snapshot.data;
              if (performance == null) return const SizedBox.shrink();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your performance',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _StatRow('Tickets booked', '${performance.tickets}'),
                      _StatRow('Total booked price',
                          '${performance.totalPrice.toStringAsFixed(2)}€'),
                      _StatRow('Your provision',
                          '${performance.provision.toStringAsFixed(2)}€'),
                    ],
                  ),
                ),
              );
            },
          ),
          if (widget.isOwner) ...[
            const SizedBox(height: 24),
            Text('Team', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<TeamPerformanceEntry>>(
              future: _teamFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return const Text('No bookings in this range yet.');
                }
                return Card(
                  child: Column(
                    children: entries
                        .map((e) => ListTile(
                              title: Text(e.nickname),
                              subtitle: Text('${e.tickets} tickets · '
                                  '${e.totalPrice.toStringAsFixed(2)}€ booked'),
                              trailing: Text(
                                '${e.provision.toStringAsFixed(2)}€',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ))
                        .toList(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
