import 'package:flutter/material.dart';

import '../../../core/models/provider_public_profile.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../services/provider_search_service.dart';

class ProviderSearchResultsScreen extends StatefulWidget {
  const ProviderSearchResultsScreen({super.key});

  @override
  State<ProviderSearchResultsScreen> createState() =>
      _ProviderSearchResultsScreenState();
}

class _ProviderSearchResultsScreenState
    extends State<ProviderSearchResultsScreen> {
  late final String _query;
  Future<List<ProviderPublicProfile>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future != null) return;
    _query = ModalRoute.of(context)?.settings.arguments as String? ?? '';
    _future = ProviderSearchService.instance.search(_query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results for "$_query"')),
      body: FutureBuilder<List<ProviderPublicProfile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingWidget(label: 'Searching...');
          }
          final results = snapshot.data ?? const [];
          if (results.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.search_off_rounded,
              title: 'No matches',
              subtitle: 'Try a service like "Plumber" or a provider\'s name.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _ProviderResultCard(provider: results[i]),
          );
        },
      ),
    );
  }
}

class _ProviderResultCard extends StatelessWidget {
  final ProviderPublicProfile provider;
  const _ProviderResultCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).pushNamed(
          RouteNames.candidateProviderProfile,
          arguments: provider.id,
        ),
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(provider.name, style: AppTextStyles.titleMedium),
        subtitle: Text(
          provider.skills.map(ServiceCategoryUi.label).join(', '),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: provider.isVerified
            ? const Icon(Icons.verified_rounded, color: AppColors.primary)
            : null,
      ),
    );
  }
}
