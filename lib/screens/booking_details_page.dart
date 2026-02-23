import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/booking_model.dart';
import '../services/api_service.dart';

class BookingDetailsPage extends StatefulWidget {
  const BookingDetailsPage({
    super.key,
    required this.initialBooking,
    required this.driverId,
  });

  final Booking initialBooking;
  final String driverId;

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  final ApiService _apiService = ApiService();

  late Booking _booking;
  bool _isLoading = false;
  bool _isConfirming = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.initialBooking;
  }

  bool get _canConfirm {
    if (!_booking.isPending || !_isAssignedToCurrentDriver) {
      return false;
    }
    return true;
  }

  bool get _canComplete {
    if (!_booking.isConfirmed || !_isAssignedToCurrentDriver) {
      return false;
    }
    return true;
  }

  bool get _isAssignedToCurrentDriver {
    final assignedId = (_booking.driverId ?? _booking.driver?.id ?? '').trim();
    return assignedId.isEmpty || assignedId == widget.driverId;
  }

  Future<void> _refreshBooking() async {
    setState(() => _isLoading = true);

    final latest = await _apiService.getBooking(_booking.id);
    if (!mounted) {
      return;
    }

    setState(() {
      if (latest != null) {
        _booking = latest;
      }
      _isLoading = false;
    });
  }

  Future<void> _confirmBooking() async {
    if (_isConfirming || _isCompleting || !_canConfirm) {
      return;
    }

    setState(() => _isConfirming = true);

    final success = await _apiService.confirmBooking(
      bookingId: _booking.id,
      driverId: widget.driverId,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      await _refreshBooking();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking confirmed successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to confirm booking. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    setState(() => _isConfirming = false);
  }

  Future<void> _completeBooking() async {
    if (_isCompleting || _isConfirming || !_canComplete) {
      return;
    }

    setState(() => _isCompleting = true);

    final success = await _apiService.completeBooking(
      bookingId: _booking.id,
      driverId: widget.driverId,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      await _refreshBooking();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking marked as completed.'),
          backgroundColor: Color(0xFF3B82F6),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to complete booking. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    setState(() => _isCompleting = false);
  }

  Future<void> _callPassenger() async {
    final phone = _booking.customerPhone.trim();
    if (phone.isEmpty) {
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (_booking.status.toLowerCase()) {
      'confirmed' => const Color(0xFF10B981),
      'pending' => const Color(0xFF3B82F6),
      'completed' => const Color(0xFF64748B),
      _ => const Color(0xFF475569),
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Trip ${_booking.bookingCode ?? _booking.shortId}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refreshBooking,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    _booking.tripType.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: statusColor.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      _booking.status.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                (_booking.vehicleName ?? 'TAXI').toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Trip Details'),
                              const SizedBox(height: 10),
                              _infoRow('Pickup', _booking.pickupLocationName),
                              _infoRow('Drop', _booking.effectiveDropoffName),
                              _infoRow(
                                'Date',
                                DateFormat(
                                  'dd MMM yyyy',
                                ).format(_booking.pickupDateTime),
                              ),
                              _infoRow(
                                'Time',
                                DateFormat(
                                  'hh:mm a',
                                ).format(_booking.pickupDateTime),
                              ),
                              if (_booking.distanceKm != null)
                                _infoRow(
                                  'Distance',
                                  '${_booking.distanceKm!.toStringAsFixed(1)} KM',
                                ),
                              if (_booking.estimatedFare != null)
                                _infoRow(
                                  'Estimated Fare',
                                  'INR ${_booking.estimatedFare!.toInt()}',
                                ),
                              const SizedBox(height: 18),
                              _sectionTitle('Passenger Details'),
                              const SizedBox(height: 10),
                              _infoRow('Name', _booking.customerName),
                              _infoRow('Phone', _booking.customerPhone),
                              const SizedBox(height: 18),
                              _sectionTitle('Payment Details'),
                              const SizedBox(height: 10),
                              _infoRow(
                                'Payment Status',
                                _booking.paymentStatus.toUpperCase(),
                              ),
                              _infoRow(
                                'Payment Type',
                                (_booking.paymentType ?? 'N/A').toUpperCase(),
                              ),
                              if ((_booking.paymentAmount ?? 0) > 0)
                                _infoRow(
                                  'Amount Paid',
                                  'INR ${_booking.paymentAmount!.toInt()}',
                                ),
                              if (_booking.driver != null) ...[
                                const SizedBox(height: 18),
                                _sectionTitle('Driver'),
                                const SizedBox(height: 10),
                                _infoRow('Name', _booking.driver!.name),
                                _infoRow('Phone', _booking.driver!.phone),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _callPassenger,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF93C5FD),
                        side: const BorderSide(color: Color(0xFF1D4ED8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Call Passenger'),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: (_canConfirm || _canComplete)
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: (_isConfirming || _isCompleting)
                      ? null
                      : (_canConfirm ? _confirmBooking : _completeBooking),
                  style: FilledButton.styleFrom(
                    backgroundColor: _canConfirm
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: (_isConfirming || _isCompleting)
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _canConfirm
                              ? Icons.check_circle_outline_rounded
                              : Icons.task_alt_rounded,
                        ),
                  label: Text(
                    _canConfirm
                        ? (_isConfirming ? 'Confirming...' : 'Confirm Booking')
                        : (_isCompleting
                              ? 'Completing...'
                              : 'Complete Booking'),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
