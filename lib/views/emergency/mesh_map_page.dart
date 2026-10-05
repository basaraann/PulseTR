import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/ble_mesh_service.dart';

/// Mesh ağındaki yakındaki kullanıcıları haritada gösterir.
/// - [focusedNode] varsa tek kişiye odaklan, navigasyon modu
/// - null ise tüm yakındakileri göster
class MeshMapPage extends StatefulWidget {
  final MeshNode? focusedNode;
  const MeshMapPage({super.key, this.focusedNode});

  @override
  State<MeshMapPage> createState() => _MeshMapPageState();
}

class _MeshMapPageState extends State<MeshMapPage> {
  final MapController _mapController = MapController();
  final BleMeshService _service = BleMeshService();

  LatLng? _myLocation;
  List<MeshNode> _nodes = [];
  StreamSubscription<List<MeshNode>>? _nodesSub;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _initNodeStream();
  }

  Future<void> _initLocation() async {
    try {
      final pos = _service.currentPosition;
      if (pos != null && mounted) {
        setState(() {
          _myLocation = LatLng(pos.latitude, pos.longitude);
        });
      } else {
        // Fallback: Geolocator'dan tek seferlik al
        final fresh = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        if (mounted) {
          setState(() {
            _myLocation = LatLng(fresh.latitude, fresh.longitude);
          });
          _centerMap();
        }
      }

      // Konum değişikliğini dinle
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _myLocation = LatLng(pos.latitude, pos.longitude);
          });
        }
      });
    } catch (e) {
      debugPrint('Konum alma hatası: $e');
    }
  }

  void _initNodeStream() {
    _nodesSub = _service.nodesStream.listen((list) {
      if (!mounted) return;
      setState(() => _nodes = list);
    });
  }

  void _centerMap() {
    if (_myLocation == null) return;
    if (widget.focusedNode != null &&
        widget.focusedNode!.latitude != null &&
        widget.focusedNode!.longitude != null) {
      // Tek kullanıcı modu: ikisini ortalayan zoom
      final target = LatLng(
        widget.focusedNode!.latitude!,
        widget.focusedNode!.longitude!,
      );
      final mid = LatLng(
        (_myLocation!.latitude + target.latitude) / 2,
        (_myLocation!.longitude + target.longitude) / 2,
      );
      _mapController.move(mid, 18);
    } else {
      _mapController.move(_myLocation!, 17);
    }
  }

  @override
  void dispose() {
    _nodesSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = widget.focusedNode != null;
    // Hangi nodeları göstereceğiz?
    final List<MeshNode> displayNodes;
    if (isFocused) {
      // Sadece odaklanılan kullanıcı
      final fresh = _nodes.firstWhere(
        (n) => n.id == widget.focusedNode!.id ||
            (n.name == widget.focusedNode!.name &&
                n.bloodType == widget.focusedNode!.bloodType),
        orElse: () => widget.focusedNode!,
      );
      displayNodes = [fresh];
    } else {
      displayNodes = _nodes.where((n) => n.hasGps).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: Text(
          isFocused
              ? widget.focusedNode!.name
              : 'Yakındaki Kullanıcılar (${displayNodes.length})',
          style: const TextStyle(fontSize: 17),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.tealAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Konumuma git',
            onPressed: _centerMap,
          ),
        ],
      ),
      body: _myLocation == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent),
            )
          : Stack(
              children: [
                _buildMap(displayNodes),
                if (isFocused) _buildFocusInfoCard(displayNodes.first),
                if (!isFocused && displayNodes.isEmpty)
                  _buildNoGpsBanner(),
              ],
            ),
    );
  }

  Widget _buildMap(List<MeshNode> nodes) {
    final markers = <Marker>[];

    // Kendi konumum
    markers.add(
      Marker(
        point: _myLocation!,
        width: 50,
        height: 50,
        child: _buildMyMarker(),
      ),
    );

    // Diğer kullanıcılar
    for (final n in nodes) {
      if (n.latitude == null || n.longitude == null) continue;
      markers.add(
        Marker(
          point: LatLng(n.latitude!, n.longitude!),
          width: 60,
          height: 70,
          child: GestureDetector(
            onTap: () => _showNodeBottomSheet(n),
            child: _buildNodeMarker(n),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.focusedNode != null &&
                widget.focusedNode!.latitude != null
            ? LatLng(
                widget.focusedNode!.latitude!,
                widget.focusedNode!.longitude!,
              )
            : _myLocation!,
        initialZoom: widget.focusedNode != null ? 18 : 17,
        minZoom: 12,
        maxZoom: 19,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.earthquake.app',
        ),
        // Odaklanmış mod: ben ve hedef arasında çizgi
        if (widget.focusedNode != null &&
            widget.focusedNode!.latitude != null &&
            widget.focusedNode!.longitude != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  _myLocation!,
                  LatLng(
                    widget.focusedNode!.latitude!,
                    widget.focusedNode!.longitude!,
                  ),
                ],
                color: widget.focusedNode!.isAlerting
                    ? Colors.redAccent
                    : Colors.tealAccent,
                strokeWidth: 3,
              ),
            ],
          ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildMyMarker() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildNodeMarker(MeshNode n) {
    final color = n.isAlerting ? Colors.redAccent : Colors.tealAccent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 0.5),
          ),
          child: Text(
            n.bloodType,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(
            n.isAlerting ? Icons.warning_amber_rounded : Icons.person,
            color: Colors.black87,
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildFocusInfoCard(MeshNode n) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: n.isAlerting
                ? Colors.redAccent.withValues(alpha: 0.6)
                : Colors.tealAccent.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (n.isAlerting ? Colors.redAccent : Colors.tealAccent)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    n.bloodType,
                    style: TextStyle(
                      color:
                          n.isAlerting ? Colors.redAccent : Colors.tealAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: n.bloodType.length > 2 ? 11 : 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n.directionText,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildMessageBadge(n.messageType),
              ],
            ),
            if (n.isAlerting) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu kullanıcı yardım istiyor — yardıma git',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBadge(MeshMsgType type) {
    Color color;
    switch (type) {
      case MeshMsgType.sos:
      case MeshMsgType.needHelp:
        color = Colors.redAccent;
        break;
      case MeshMsgType.safe:
        color = Colors.greenAccent;
        break;
      case MeshMsgType.presence:
        color = Colors.blueAccent;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildNoGpsBanner() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amberAccent, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Yakındaki kullanıcılarda GPS verisi yok. '
                'Listede mesafe/yön RSSI tahminine göredir.',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNodeBottomSheet(MeshNode n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      (n.isAlerting ? Colors.redAccent : Colors.tealAccent)
                          .withValues(alpha: 0.2),
                  child: Text(
                    n.bloodType,
                    style: TextStyle(
                      color: n.isAlerting
                          ? Colors.redAccent
                          : Colors.tealAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: n.bloodType.length > 2 ? 11 : 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        n.directionText,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildMessageBadge(n.messageType),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.navigation),
                label: const Text(
                  'Bu kullanıcıya odaklan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MeshMapPage(focusedNode: n),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
