// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../data/store_profile.dart';

class StoreSelectionPage extends StatefulWidget {
  final Future<void> Function(StoreProfile) onSelected;
  const StoreSelectionPage({super.key, required this.onSelected});
  @override
  State<StoreSelectionPage> createState() => _StoreSelectionPageState();
}

class _StoreSelectionPageState extends State<StoreSelectionPage> {
  bool opening = false;
  String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.storefront,
                  size: 64,
                  color: Color(0xFF086EEB),
                ),
                const SizedBox(height: 20),
                Text(
                  'Chọn cửa hàng',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chọn cửa hàng để đăng nhập và làm việc.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                for (final store in StoreProfile.stores)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.store),
                      label: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text('Cửa hàng ${store.name}'),
                      ),
                      onPressed: opening
                          ? null
                          : () async {
                              setState(() {
                                opening = true;
                                error = null;
                              });
                              try {
                                await widget.onSelected(store);
                              } catch (_) {
                                if (mounted) {
                                  setState(() {
                                    opening = false;
                                    error =
                                        'Chưa mở được cửa hàng. Hãy thử lại.';
                                  });
                                }
                              }
                            },
                    ),
                  ),
                if (opening) const Center(child: CircularProgressIndicator()),
                if (error != null) Text(error!, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
