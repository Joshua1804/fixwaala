import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../../features/payment/models/payment_model.dart';
import '../../core/admin_route_names.dart';
import '../../widgets/admin_data_table.dart';
import '../../widgets/admin_filter_dropdown.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_pagination_bar.dart';
import '../../widgets/admin_state_views.dart';
import '../../widgets/admin_status_chip.dart';
import 'services/admin_payment_service.dart';

String paymentStatusLabel(PaymentStatus status) => switch (status) {
  PaymentStatus.pending => 'Pending',
  PaymentStatus.processing => 'Processing',
  PaymentStatus.success => 'Success',
  PaymentStatus.failed => 'Failed',
};

AdminTone paymentStatusTone(PaymentStatus status) => switch (status) {
  PaymentStatus.pending => AdminTone.neutral,
  PaymentStatus.processing => AdminTone.neutral,
  PaymentStatus.success => AdminTone.good,
  PaymentStatus.failed => AdminTone.bad,
};

String disputeStatusLabel(PaymentDisputeStatus status) => switch (status) {
  PaymentDisputeStatus.none => 'None',
  PaymentDisputeStatus.disputed => 'Disputed',
  PaymentDisputeStatus.resolved => 'Resolved',
  PaymentDisputeStatus.refunded => 'Refunded',
};

AdminTone disputeStatusTone(PaymentDisputeStatus status) => switch (status) {
  PaymentDisputeStatus.none => AdminTone.neutral,
  PaymentDisputeStatus.disputed => AdminTone.bad,
  PaymentDisputeStatus.resolved => AdminTone.good,
  PaymentDisputeStatus.refunded => AdminTone.warning,
};

class AdminPaymentListScreen extends StatefulWidget {
  const AdminPaymentListScreen({super.key});

  @override
  State<AdminPaymentListScreen> createState() => _AdminPaymentListScreenState();
}

class _AdminPaymentListScreenState extends State<AdminPaymentListScreen> {
  PaymentDisputeStatus? _disputeStatus;
  final List<fs.DocumentSnapshot<Map<String, dynamic>>?> _cursorStack = [null];
  int _pageIndex = 0;
  Future<PaymentPage>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AdminPaymentService.instance.fetchPage(
      disputeStatus: _disputeStatus,
      startAfter: _cursorStack[_pageIndex],
    );
  }

  void _reset() => setState(() {
    _cursorStack
      ..clear()
      ..add(null);
    _pageIndex = 0;
    _load();
  });

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Payments',
      subtitle: 'Simulated payment records and dispute handling.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminFilterDropdown<PaymentDisputeStatus>(
            label: 'Dispute status',
            value: _disputeStatus,
            options: PaymentDisputeStatus.values,
            labelBuilder: disputeStatusLabel,
            onChanged: (v) {
              setState(() => _disputeStatus = v);
              _reset();
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<PaymentPage>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AdminLoadingView();
              }
              if (snapshot.hasError) {
                return AdminErrorView(error: snapshot.error!, onRetry: _reset);
              }
              final page = snapshot.data!;
              if (page.payments.isEmpty && _pageIndex == 0) {
                return const AdminEmptyView(
                  title: 'No payments',
                  message: 'No payments match this filter.',
                  icon: Icons.payments_outlined,
                );
              }
              return Column(
                children: [
                  AdminTableCard(
                    columns: const [
                      DataColumn(label: Text('Amount')),
                      DataColumn(label: Text('Method')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Dispute')),
                      DataColumn(label: Text('Processed')),
                    ],
                    rows: page.payments.map((payment) {
                      return DataRow(
                        onSelectChanged: (_) => Navigator.of(context).pushNamed(
                          AdminRouteNames.paymentDetail,
                          arguments: payment.id,
                        ),
                        cells: [
                          DataCell(Text('₹${payment.amount.toStringAsFixed(0)}')),
                          DataCell(Text(payment.method)),
                          DataCell(
                            AdminStatusChip.semantic(
                              paymentStatusLabel(payment.status),
                              tone: paymentStatusTone(payment.status),
                            ),
                          ),
                          DataCell(
                            payment.disputeStatus == PaymentDisputeStatus.none
                                ? const Text('—', style: TextStyle(color: AppColors.textHint))
                                : AdminStatusChip.semantic(
                                    disputeStatusLabel(payment.disputeStatus),
                                    tone: disputeStatusTone(payment.disputeStatus),
                                  ),
                          ),
                          DataCell(Text(RelativeTime.format(payment.processedAt))),
                        ],
                      );
                    }).toList(),
                  ),
                  AdminPaginationBar(
                    pageNumber: _pageIndex + 1,
                    pageSize: 25,
                    currentCount: page.payments.length,
                    hasPrevious: _pageIndex > 0,
                    hasNext: page.hasMore,
                    isLoading: false,
                    onPrevious: _pageIndex == 0
                        ? null
                        : () => setState(() {
                            _pageIndex--;
                            _load();
                          }),
                    onNext: () => setState(() {
                      if (_pageIndex + 1 >= _cursorStack.length) {
                        _cursorStack.add(page.lastDoc);
                      }
                      _pageIndex++;
                      _load();
                    }),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
