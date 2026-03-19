import 'package:flutter/material.dart';
import '../auth/common_widgets.dart';
import '../../services/api_service.dart';

/// Post-ride rating screen.
class RateRideScreen extends StatefulWidget {
  final String rideId;
  final String ratedUserId;
  final String ratedUserName;
  final bool isDriver; // true = rating the driver, false = rating a rider
  final bool demoMode;

  const RateRideScreen({
    super.key,
    required this.rideId,
    required this.ratedUserId,
    required this.ratedUserName,
    this.isDriver = true,
    this.demoMode = false,
  });

  @override
  State<RateRideScreen> createState() => _RateRideScreenState();
}

class _RateRideScreenState extends State<RateRideScreen> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingSummary = true;
  bool _hasAlreadyRated = false;
  String? _loadError;
  double? _averageRating;
  int _totalRatings = 0;

  @override
  void initState() {
    super.initState();
    _loadRatingContext();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadRatingContext() async {
    setState(() {
      _isLoadingSummary = true;
      _loadError = null;
    });

    if (widget.demoMode) {
      if (!mounted) return;
      setState(() {
        _isLoadingSummary = false;
        _hasAlreadyRated = false;
        _averageRating = 4.8;
        _totalRatings = 29;
      });
      return;
    }

    final profileRes = await UserApiService.getMyProfile();
    final summaryRes = await RatingApiService.getUserRatingSummary(
      widget.ratedUserId,
    );
    final rideRatingsRes = await RatingApiService.getRideRatings(widget.rideId);

    if (!mounted) return;

    String? currentUserId;
    if (profileRes.success && profileRes.data is Map<String, dynamic>) {
      currentUserId = (profileRes.data as Map<String, dynamic>)['user_id']
          ?.toString();
    }

    bool alreadyRated = false;
    if (currentUserId != null && rideRatingsRes.data is List) {
      for (final item in rideRatingsRes.data as List) {
        if (item is Map<String, dynamic> &&
            item['rater_id']?.toString() == currentUserId &&
            item['rated_user_id']?.toString() == widget.ratedUserId) {
          alreadyRated = true;
          break;
        }
      }
    }

    setState(() {
      _isLoadingSummary = false;
      _hasAlreadyRated = alreadyRated;
      _averageRating =
          summaryRes.success && summaryRes.data is Map<String, dynamic>
          ? (summaryRes.data['average_rating'] as num?)?.toDouble()
          : null;
      _totalRatings =
          summaryRes.success && summaryRes.data is Map<String, dynamic>
          ? (summaryRes.data['total_ratings'] as num?)?.toInt() ?? 0
          : 0;
      _loadError =
          (!summaryRes.success &&
              !rideRatingsRes.success &&
              !profileRes.success)
          ? (summaryRes.error ?? rideRatingsRes.error ?? profileRes.error)
          : null;
    });
  }

  Future<void> _submitRating() async {
    if (_hasAlreadyRated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You already submitted a rating for this ride.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a rating'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    if (widget.demoMode) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _hasAlreadyRated = true;
      });
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Demo rating saved locally for the walkthrough.'),
          backgroundColor: kPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final res = await RatingApiService.submitRating(
      rideId: widget.rideId,
      ratedUserId: widget.ratedUserId,
      ratingValue: _rating,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res.success) {
        _hasAlreadyRated = true;
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rating submitted! Thank you.'),
            backgroundColor: kPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.error ?? 'Failed to submit rating'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(bottom: BorderSide(color: kCardBorder)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Rate Your Ride',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isDriver ? Icons.directions_car : Icons.person,
                        color: kPrimary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      widget.ratedUserName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isDriver ? 'Your Driver' : 'Your Rider',
                      style: const TextStyle(color: kMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kCardBorder),
                      ),
                      child: _isLoadingSummary
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: kPrimary,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Trust Summary',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _totalRatings > 0
                                      ? 'Average rating ${_averageRating?.toStringAsFixed(1) ?? '0.0'} from $_totalRatings rides'
                                      : 'No rating history yet for this user',
                                  style: const TextStyle(
                                    color: kMuted,
                                    fontSize: 13,
                                  ),
                                ),
                                if (_hasAlreadyRated) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'You already rated this person for this ride.',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ] else if (_loadError != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _loadError!,
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),

                    if (widget.demoMode) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: kPrimary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Text(
                          'Demo Mode stores this rating only inside the presentation flow. No backend write happens from this screen.',
                          style: TextStyle(color: kMuted, fontSize: 12),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    const Text(
                      'How was your experience?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        return GestureDetector(
                          onTap: () => setState(() => _rating = starValue),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              starValue <= _rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: starValue <= _rating
                                  ? Colors.amber
                                  : kMuted,
                              size: 44,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      switch (_rating) {
                        1 => 'Poor',
                        2 => 'Fair',
                        3 => 'Good',
                        4 => 'Great',
                        5 => 'Excellent!',
                        _ => 'Tap to rate',
                      },
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _rating > 0 ? kPrimary : kMuted,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Comment
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kCardBorder),
                      ),
                      child: TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Leave a comment (optional)',
                          hintStyle: TextStyle(
                            color: kMuted.withValues(alpha: 0.6),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Submit button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(top: BorderSide(color: kCardBorder)),
              ),
              child: AuthButton(
                label: _hasAlreadyRated
                    ? 'Rating Already Submitted'
                    : _isSubmitting
                    ? 'Submitting...'
                    : 'Submit Rating',
                icon: Icons.send,
                onPressed: _isSubmitting || _hasAlreadyRated
                    ? null
                    : _submitRating,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
