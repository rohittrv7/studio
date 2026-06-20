import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../bookings/data/repositories/bookings_repository.dart';

class PlansManagerScreen extends ConsumerWidget {
  const PlansManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const gold = Color(0xFFE8B86D);
    final plansAsync = ref.watch(plansListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pricing Plans'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: plansAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: gold, strokeWidth: 2),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.grey, size: 40),
                const SizedBox(height: 12),
                Text('Failed to load plans: $err', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.read(plansListProvider.notifier).loadPlans(),
                  child: const Text('Retry', style: TextStyle(color: gold)),
                ),
              ],
            ),
          ),
          data: (plans) {
            if (plans.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.payments_outlined, color: gold, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No pricing plans created yet.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create pricing packages for clients to select.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                return Dismissible(
                  key: Key(plan.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  ),
                  confirmDismiss: (dir) async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF161616)
                            : const Color(0xFFF7F7F7),
                        title: Text(
                          'Delete Plan',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                        ),
                        content: Text(
                          'Are you sure you want to delete "${plan.name}"?',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final success = await ref.read(plansListProvider.notifier).deletePlan(plan.id);
                      if (context.mounted && !success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to delete plan. It might be in use.')),
                        );
                      }
                      return success;
                    }
                    return false;
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF161616)
                          : const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF2E2E2E)
                            : const Color(0xFFE5E5E5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                plan.name,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '₹${plan.price.toStringAsFixed(0)}',
                              style: const TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plan.description,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: gold,
        foregroundColor: Colors.black,
        onPressed: () => _showCreatePlanDialog(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showCreatePlanDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    const gold = Color(0xFFE8B86D);

    showDialog<void>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
          title: Text(
            'Create Plan',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: const InputDecoration(
                      hintText: 'Plan Name (e.g. Wedding Package)',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceCtrl,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'Price (INR)',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Plan Details (session hours, photo counts, edits, deliveries)',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final name = nameCtrl.text.trim();
                final price = double.parse(priceCtrl.text.trim());
                final desc = descCtrl.text.trim();

                Navigator.pop(context);
                final success = await ref.read(plansListProvider.notifier).createPlan(name, price, desc);
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Plan created successfully!')),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Failed to create plan. Try again.')),
                  );
                }
              },
              child: const Text('Create', style: TextStyle(color: gold)),
            ),
          ],
        );
      },
    );
  }
}
