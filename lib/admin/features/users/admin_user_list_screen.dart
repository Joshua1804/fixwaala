import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../core/admin_route_names.dart';
import '../../widgets/admin_data_table.dart';
import '../../widgets/admin_filter_dropdown.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_pagination_bar.dart';
import '../../widgets/admin_search_field.dart';
import '../../widgets/admin_state_views.dart';
import '../../widgets/admin_status_chip.dart';
import 'services/admin_user_service.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  UserRole? _role;
  AccountStatus? _status;
  String _searchTerm = '';

  final List<fs.DocumentSnapshot<Map<String, dynamic>>?> _cursorStack = [null];
  int _pageIndex = 0;

  Future<UserPage>? _pageFuture;
  Future<List<AppUser>>? _searchFuture;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  void _loadPage() {
    _pageFuture = AdminUserService.instance.fetchPage(
      role: _role,
      status: _status,
      startAfter: _cursorStack[_pageIndex],
    );
  }

  void _resetAndReload() {
    setState(() {
      _cursorStack
        ..clear()
        ..add(null);
      _pageIndex = 0;
      _loadPage();
    });
  }

  void _onSearchChanged(String term) {
    setState(() {
      _searchTerm = term;
      _searchFuture = term.isEmpty
          ? null
          : AdminUserService.instance.search(term);
    });
  }

  void _nextPage(fs.DocumentSnapshot<Map<String, dynamic>>? lastDoc) {
    setState(() {
      if (_pageIndex + 1 >= _cursorStack.length) {
        _cursorStack.add(lastDoc);
      }
      _pageIndex++;
      _loadPage();
    });
  }

  void _previousPage() {
    if (_pageIndex == 0) return;
    setState(() {
      _pageIndex--;
      _loadPage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchTerm.isNotEmpty;
    return AdminPageScaffold(
      title: 'Users',
      subtitle: 'Customers and providers on the platform.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AdminSearchField(
                hint: 'Exact email or name starts with…',
                onChanged: _onSearchChanged,
                width: 320,
              ),
              AdminFilterDropdown<UserRole>(
                label: 'Role',
                value: _role,
                options: UserRole.values,
                labelBuilder: (r) =>
                    r == UserRole.customer ? 'Customer' : 'Provider',
                onChanged: (v) {
                  setState(() {
                    _role = v;
                    if (v == null) _status = null;
                  });
                  _resetAndReload();
                },
              ),
              AdminFilterDropdown<AccountStatus>(
                label: 'Status',
                value: _status,
                options: AccountStatus.values,
                labelBuilder: (s) => s.name,
                onChanged: _role == null
                    ? null
                    : (v) {
                        setState(() => _status = v);
                        _resetAndReload();
                      },
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isSearching) _buildSearchResults() else _buildBrowseTable(),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<AppUser>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AdminLoadingView();
        }
        if (snapshot.hasError) {
          return AdminErrorView(
            error: snapshot.error!,
            onRetry: () => _onSearchChanged(_searchTerm),
          );
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return AdminEmptyView(
            title: 'No matches',
            message: 'No user matches "$_searchTerm".',
            icon: Icons.search_off_rounded,
          );
        }
        return _UserTable(users: users);
      },
    );
  }

  Widget _buildBrowseTable() {
    return FutureBuilder<UserPage>(
      future: _pageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AdminLoadingView();
        }
        if (snapshot.hasError) {
          return AdminErrorView(
            error: snapshot.error!,
            onRetry: _resetAndReload,
          );
        }
        final page = snapshot.data!;
        if (page.users.isEmpty && _pageIndex == 0) {
          return const AdminEmptyView(
            title: 'No users yet',
            message: 'Users appear here once they sign up in the app.',
            icon: Icons.people_outline_rounded,
          );
        }
        return Column(
          children: [
            _UserTable(users: page.users),
            AdminPaginationBar(
              pageNumber: _pageIndex + 1,
              pageSize: 25,
              currentCount: page.users.length,
              hasPrevious: _pageIndex > 0,
              hasNext: page.hasMore,
              isLoading: false,
              onPrevious: _previousPage,
              onNext: () => _nextPage(page.lastDoc),
            ),
          ],
        );
      },
    );
  }
}

class _UserTable extends StatelessWidget {
  final List<AppUser> users;
  const _UserTable({required this.users});

  @override
  Widget build(BuildContext context) {
    return AdminTableCard(
      columns: const [
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Role')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Verified')),
        DataColumn(label: Text('Joined')),
      ],
      rows: users.map((user) {
        return DataRow(
          onSelectChanged: (_) => Navigator.of(
            context,
          ).pushNamed(AdminRouteNames.userDetail, arguments: user.id),
          cells: [
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      initialsOf(user.name),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(user.name?.trim().isNotEmpty == true ? user.name! : '—'),
                ],
              ),
            ),
            DataCell(Text(user.email)),
            DataCell(
              AdminStatusChip.semantic(
                user.role == UserRole.customer ? 'Customer' : 'Provider',
                tone: user.role == UserRole.customer
                    ? AdminTone.neutral
                    : AdminTone.good,
              ),
            ),
            DataCell(_statusChip(user.accountStatus)),
            DataCell(
              user.role == UserRole.provider
                  ? Icon(
                      user.isVerified
                          ? Icons.verified_rounded
                          : Icons.remove_circle_outline_rounded,
                      size: 18,
                      color: user.isVerified
                          ? AppColors.success
                          : AppColors.textHint,
                    )
                  : const Text('—'),
            ),
            DataCell(Text(RelativeTime.format(user.createdAt))),
          ],
        );
      }).toList(),
    );
  }

  Widget _statusChip(AccountStatus status) {
    return switch (status) {
      AccountStatus.active => AdminStatusChip.semantic(
        'Active',
        tone: AdminTone.good,
      ),
      AccountStatus.restricted => AdminStatusChip.semantic(
        'Restricted',
        tone: AdminTone.warning,
      ),
      AccountStatus.suspended => AdminStatusChip.semantic(
        'Suspended',
        tone: AdminTone.bad,
      ),
    };
  }
}
