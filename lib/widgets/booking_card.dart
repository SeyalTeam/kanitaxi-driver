import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/booking_model.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('hh:mm a');
    final dateOnlyFormat = DateFormat('dd MMM');

    final cardColor = switch (booking.status.toLowerCase()) {
      'confirmed' => const Color(0xFF10B981),
      'pending' => const Color(0xFF3B82F6),
      'completed' => const Color(0xFF64748B),
      _ => const Color(0xFF475569),
    };

    const textColor = Colors.white;
    const subTextColor = Colors.white70;

    final pickupLabel = booking.pickupLocationName.split(',').first.trim();
    final dropoffLabel = booking.effectiveDropoffName.split(',').first.trim();

    final tripTypeLabel = booking.tripType
        .replaceAll('multilocation', 'Tour')
        .toUpperCase();

    final bookingCode = booking.bookingCode?.trim();
    final bookingCodeLabel = (bookingCode != null && bookingCode.isNotEmpty)
        ? '#$bookingCode'
        : booking.shortId;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            tripTypeLabel,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (booking.vehicleName != null &&
                              booking.vehicleName!.trim().isNotEmpty)
                            Text(
                              booking.vehicleName!.toUpperCase(),
                              style: const TextStyle(
                                color: subTextColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Text(
                            bookingCodeLabel,
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              booking.status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getPaymentStatusColor(
                                booking.paymentStatus,
                              ).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _getPaymentStatusColor(
                                  booking.paymentStatus,
                                ).withValues(alpha: 0.8),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              booking.paymentStatus.toUpperCase(),
                              style: TextStyle(
                                color: _getPaymentStatusColor(
                                  booking.paymentStatus,
                                ),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${booking.estimatedFare?.toInt() ?? 0}',
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if ((booking.paymentAmount ?? 0) > 0)
                      Text(
                        'PAID: ₹${booking.paymentAmount!.toInt()}${booking.paymentType != null ? " (${booking.paymentType})" : ""}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeFormat.format(booking.pickupDateTime),
                        style: const TextStyle(
                          color: subTextColor,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateOnlyFormat
                            .format(booking.pickupDateTime)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Text(
                        '${booking.distanceKm?.toStringAsFixed(1) ?? "0"} KM',
                        style: const TextStyle(
                          color: subTextColor,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 3,
                            backgroundColor: textColor,
                          ),
                          Expanded(
                            child: Container(height: 1, color: subTextColor),
                          ),
                          const CircleAvatar(
                            radius: 3,
                            backgroundColor: textColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        booking.dropDateTime != null
                            ? timeFormat.format(booking.dropDateTime!)
                            : '--:--',
                        style: const TextStyle(
                          color: subTextColor,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.dropDateTime != null
                            ? dateOnlyFormat
                                  .format(booking.dropDateTime!)
                                  .toUpperCase()
                            : 'TBD',
                        style: const TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    pickupLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    dropoffLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline, color: subTextColor, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    booking.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textColor, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.phone_outlined, color: subTextColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  booking.customerPhone,
                  style: const TextStyle(color: textColor, fontSize: 12),
                ),
                if (bookingCode != null && bookingCode.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.tag, color: subTextColor, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    bookingCode,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const Spacer(),
                const Icon(Icons.info_outline, color: textColor, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.greenAccent;
      case 'partial':
        return Colors.orangeAccent;
      case 'failed':
        return Colors.redAccent;
      case 'unpaid':
      default:
        return Colors.white;
    }
  }
}
