import 'detector_service.dart';

enum PlacementStatus {
  centered,
  moveLeft,
  moveRight,
  moveUp,
  moveDown,
  tooClose,
  tooFar,
  noObject,
}

class GuidanceResult {
  final PlacementStatus status;
  final String message;
  final int placementScore; // 0–100

  GuidanceResult({
    required this.status,
    required this.message,
    required this.placementScore,
  });
}

class GuidanceService {
  // Ideal: object should occupy 30%–70% of frame
  static const double _minObjectSize = 0.30;
  static const double _maxObjectSize = 0.70;

  // Tolerance around center (±10%)
  static const double _centerTolerance = 0.10;

  GuidanceResult analyze(List<DetectionResult> detections) {
    if (detections.isEmpty) {
      return GuidanceResult(
        status: PlacementStatus.noObject,
        message: 'No product detected. Point camera at your product.',
        placementScore: 0,
      );
    }

    // Use highest-confidence detection
    final det = detections.first;

    final objWidth = det.right - det.left;
    final objHeight = det.bottom - det.top;
    final objArea = objWidth * objHeight;

    // Too close / too far
    if (objArea > _maxObjectSize) {
      return GuidanceResult(
        status: PlacementStatus.tooClose,
        message: 'Too close — move camera back.',
        placementScore: 30,
      );
    }
    if (objArea < _minObjectSize * _minObjectSize) {
      return GuidanceResult(
        status: PlacementStatus.tooFar,
        message: 'Too far — move camera closer.',
        placementScore: 30,
      );
    }

    // Check horizontal alignment
    final cx = det.centerX; // 0.0 = left edge, 1.0 = right edge
    final cy = det.centerY;

    if (cx < 0.5 - _centerTolerance) {
      return GuidanceResult(
        status: PlacementStatus.moveRight,
        message: 'Move product right ➡',
        placementScore: 55,
      );
    }
    if (cx > 0.5 + _centerTolerance) {
      return GuidanceResult(
        status: PlacementStatus.moveLeft,
        message: 'Move product left ⬅',
        placementScore: 55,
      );
    }
    if (cy < 0.5 - _centerTolerance) {
      return GuidanceResult(
        status: PlacementStatus.moveDown,
        message: 'Move product down ⬇',
        placementScore: 55,
      );
    }
    if (cy > 0.5 + _centerTolerance) {
      return GuidanceResult(
        status: PlacementStatus.moveUp,
        message: 'Move product up ⬆',
        placementScore: 55,
      );
    }

    // Centered — compute score based on how close to perfect center
    final distFromCenter =
        ((cx - 0.5).abs() + (cy - 0.5).abs()) / 2;
    final score = ((1.0 - distFromCenter / _centerTolerance) * 100)
        .clamp(80, 100)
        .toInt();

    return GuidanceResult(
      status: PlacementStatus.centered,
      message: '✅ Product centered — ready to capture!',
      placementScore: score,
    );
  }
}