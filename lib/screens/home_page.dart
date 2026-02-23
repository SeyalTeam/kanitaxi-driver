import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/booking_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/booking_card.dart';
import 'booking_details_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  static const String _statusAll = 'all';
  static const List<String> _statusFilters = [
    _statusAll,
    'pending',
    'confirmed',
    'completed',
  ];

  Timer? _pollingTimer;
  bool _isLoading = true;
  bool _isFetching = false;
  String? _error;
  List<Booking> _bookings = const [];
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  String _selectedStatus = _statusAll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh(showLoader: true);
      _pollingTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _refresh(showLoader: false),
      );
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({required bool showLoader}) async {
    if (_isFetching) {
      return;
    }

    final driverId = context.read<AuthProvider>().driverId;
    if (driverId == null || driverId.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Driver profile not found for this account.';
        _bookings = const [];
      });
      return;
    }

    _isFetching = true;
    if (mounted && showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final bookings = await _apiService.getAssignedBookings(driverId);
      if (!mounted) {
        return;
      }

      setState(() {
        _bookings = bookings;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error = 'Could not load your assigned bookings.';
      });
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
  }

  Future<void> _openBooking(Booking booking) async {
    final driverId = context.read<AuthProvider>().driverId;
    if (driverId == null || driverId.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BookingDetailsPage(initialBooking: booking, driverId: driverId),
      ),
    );

    await _refresh(showLoader: false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0E172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Bookings',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              auth.displayName,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _refresh(showLoader: false),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _refresh(showLoader: true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredBookings = _filterBookings();

    return RefreshIndicator(
      onRefresh: () => _refresh(showLoader: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 0, bottom: 24),
        children: [
          _buildCalendarStrip(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Bookings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStatusFilterChips(),
                const SizedBox(height: 16),
                if (_bookings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No bookings assigned right now.',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                else if (filteredBookings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No bookings for this date',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                else
                  ...filteredBookings.map(
                    (booking) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: BookingCard(
                        booking: booking,
                        onTap: () => _openBooking(booking),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Booking> _filterBookings() {
    final selectedDay = DateUtils.dateOnly(_selectedDate);
    final filtered = _bookings.where((booking) {
      final bookingDay = DateUtils.dateOnly(booking.pickupDateTime);
      if (!DateUtils.isSameDay(selectedDay, bookingDay)) {
        return false;
      }
      if (_selectedStatus == _statusAll) {
        return true;
      }
      return booking.status.toLowerCase() == _selectedStatus;
    }).toList();

    filtered.sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));
    return filtered;
  }

  List<DateTime> _visibleCalendarDays() {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = List<DateTime>.generate(
      21,
      (index) => today.add(Duration(days: index)),
    );
    final hasSelectedDay = days.any(
      (day) => DateUtils.isSameDay(day, _selectedDate),
    );
    if (!hasSelectedDay) {
      days.add(DateUtils.dateOnly(_selectedDate));
      days.sort();
    }
    return days;
  }

  Widget _buildCalendarStrip() {
    final monthLabel = DateFormat(
      'MMMM yyyy',
    ).format(_selectedDate).toUpperCase();
    final calendarDays = _visibleCalendarDays();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            monthLabel,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: calendarDays.map((date) {
              final isSelected = DateUtils.isSameDay(date, _selectedDate);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = DateUtils.dateOnly(date);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  width: 55,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          )
                        : null,
                    color: isSelected
                        ? null
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFF3B82F6,
                              ).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('EEE').format(date).toUpperCase(),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        date.day.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilterChips() {
    return Row(
      children: _statusFilters.map((status) {
        final isSelected = _selectedStatus == status;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedStatus = status;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              _statusLabel(status),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case _statusAll:
        return 'All';
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}
