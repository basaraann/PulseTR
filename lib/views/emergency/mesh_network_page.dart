import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/ble_mesh_service.dart';
import '../../services/user_profile_service.dart';
import 'mesh_map_page.dart';

class MeshNetworkPage extends StatefulWidget {
  const MeshNetworkPage({super.key});

  @override
  State<MeshNetworkPage> createState() => _MeshNetworkPageState();
}

class _MeshNetworkPageState extends State<MeshNetworkPage>
    with SingleTickerProviderStateMixin {
  final BleMeshService _service = BleMeshService();
  final UserProfileService _profileService = UserProfileService();
  late AnimationController _radarController;

  UserProfile? _myProfile;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _loadAndStart();
  }

  Future<void> _loadAndStart() async {
    final p = await _profileService.load();
    if (!mounted) return;
    setState(() => _myProfile = p);
    await _service.startScan();
    // Profil eksikse yayını otomatik başlatma
    if (p.isComplete) {
      await _service.startBroadcast(msgType: MeshMsgType.presence);
    }
  }

  @override
  void dispose() {
    _service.stopScan();
    _service.stopBroadcast();
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _setMessage(MeshMsgType type) async {
    if (_service.isBroadcasting) {
      await _service.updateBroadcastMessage(type);
    } else {
      await _service.startBroadcast(msgType: type);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Yakındaki Kullanıcılar'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.tealAccent,
        actions: [
          StreamBuilder<List<MeshNode>>(
            stream: _service.nodesStream,
            builder: (_, snap) {
              final hasGpsNodes =
                  (snap.data ?? []).any((n) => n.hasGps);
              return IconButton(
                icon: const Icon(Icons.map_outlined),
                tooltip: 'Haritada göster',
                onPressed: hasGpsNodes
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MeshMapPage(),
                          ),
                        )
                    : null,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildMyStatusCard(),
            _buildStatusBar(),
            Expanded(child: _buildNodeList()),
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyStatusCard() {
    final p = _myProfile;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.tealAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.tealAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p?.fullName.isNotEmpty == true ? p!.fullName : 'Profil yok',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kan: ${p?.bloodType ?? "?"}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _service.isBroadcastingNotifier,
            builder: (_, broadcasting, __) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: broadcasting
                      ? Colors.greenAccent.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            broadcasting ? Colors.greenAccent : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      broadcasting ? 'Yayında' : 'Kapalı',
                      style: TextStyle(
                        color: broadcasting
                            ? Colors.greenAccent
                            : Colors.grey[400],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return ValueListenableBuilder<String>(
      valueListenable: _service.statusNotifier,
      builder: (_, status, __) {
        if (status.isEmpty) return const SizedBox(height: 4);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          alignment: Alignment.centerLeft,
          child: Text(
            status,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        );
      },
    );
  }

  Widget _buildNodeList() {
    return StreamBuilder<List<MeshNode>>(
      stream: _service.nodesStream,
      builder: (context, snap) {
        final nodes = snap.data ?? [];
        if (nodes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (_, __) => Transform.scale(
                    scale: 1 + (_radarController.value * 0.3),
                    child: Icon(
                      Icons.bluetooth_searching,
                      color: Colors.tealAccent
                          .withValues(alpha: 1 - _radarController.value),
                      size: 60,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Yakında kullanıcı yok',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aramaya devam ediliyor...',
                  style: TextStyle(color: Colors.grey[700], fontSize: 11),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: nodes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _buildNodeCard(nodes[i]),
        );
      },
    );
  }

  Widget _buildNodeCard(MeshNode node) {
    final isAlert = node.isAlerting;
    final accentColor =
        isAlert ? Colors.redAccent : Colors.tealAccent;
    final canShowOnMap = node.hasGps;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canShowOnMap
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeshMapPage(focusedNode: node),
                  ),
                )
            : () => _showNoGpsSnackbar(),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withValues(alpha: isAlert ? 0.6 : 0.15),
              width: isAlert ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildBloodAvatar(node.bloodType, accentColor),
                    const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              node.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildMessageBadge(node.messageType),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            node.hasGps
                                ? Icons.location_on
                                : Icons.signal_cellular_alt,
                            size: 13,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            node.directionText,
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!node.hasGps)
                            Text(
                              '~tahmini',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (node.hasGps && node.bearingDegrees != null)
                  _buildDirectionArrow(node.bearingDegrees!),
              ],
            ),
            if (isAlert) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Bu kullanıcı yardım istiyor',
                      style: TextStyle(
                        color: Colors.red[200],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSignalBars(node.rssi),
                const SizedBox(width: 6),
                Text(
                  '${node.rssi} dBm',
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
                const Spacer(),
                if (canShowOnMap)
                  const Icon(
                    Icons.map_outlined,
                    color: Colors.tealAccent,
                    size: 12,
                  ),
                if (canShowOnMap) const SizedBox(width: 4),
                Text(
                  canShowOnMap ? 'Haritada gör' : 'GPS yok',
                  style: TextStyle(
                    color: canShowOnMap
                        ? Colors.tealAccent.withValues(alpha: 0.7)
                        : Colors.grey[700],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  void _showNoGpsSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bu kullanıcı henüz GPS konumu paylaşmıyor'),
        backgroundColor: Color(0xFF1E293B),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildBloodAvatar(String blood, Color accent) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        blood,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.bold,
          fontSize: blood.length > 2 ? 11 : 13,
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

  Widget _buildDirectionArrow(double bearingDegrees) {
    // Cihazın kendi heading'ine göre rölatif açı
    final heading = _service.currentHeading ?? 0;
    final relative = (bearingDegrees - heading) * (math.pi / 180);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.tealAccent.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Transform.rotate(
        angle: relative,
        child: const Icon(
          Icons.navigation,
          color: Colors.tealAccent,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildSignalBars(int rssi) {
    int bars = 0;
    if (rssi > -90) bars = 1;
    if (rssi > -80) bars = 2;
    if (rssi > -70) bars = 3;
    if (rssi > -60) bars = 4;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        return Container(
          margin: const EdgeInsets.only(right: 2),
          width: 3,
          height: 4.0 + (i * 2),
          decoration: BoxDecoration(
            color: i < bars ? Colors.greenAccent : Colors.grey[800],
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: _service.isBroadcastingNotifier,
        builder: (_, isBroadcasting, __) {
          final current = _service.currentMessageType;
          return Row(
            children: [
              Expanded(
                child: _statusButton(
                  label: 'Yakında',
                  icon: Icons.person_pin_circle,
                  color: Colors.blueAccent,
                  active: isBroadcasting && current == MeshMsgType.presence,
                  onTap: () => _setMessage(MeshMsgType.presence),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusButton(
                  label: 'Güvende',
                  icon: Icons.check_circle,
                  color: Colors.greenAccent,
                  active: isBroadcasting && current == MeshMsgType.safe,
                  onTap: () => _setMessage(MeshMsgType.safe),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusButton(
                  label: 'SOS',
                  icon: Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  active: isBroadcasting && current == MeshMsgType.sos,
                  onTap: () => _setMessage(MeshMsgType.sos),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? color : Colors.grey[500], size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? color : Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
