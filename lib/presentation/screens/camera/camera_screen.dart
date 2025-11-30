class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    final cameras = await availableCameras();
    controller = CameraController(cameras.first, ResolutionPreset.medium);
    await controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(controller!),

          // Simple overlay (Rule of Thirds)
          CustomPaint(
            painter: GridOverlayPainter(),
            child: Container(),
          ),
          
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: () async {
                  final file = await controller!.takePicture();
                  context.go('/feedback', extra: file.path);
                },
                child: const Icon(Icons.camera_alt),
              ),
            ),
          )
        ],
      ),
    );
  }
}
