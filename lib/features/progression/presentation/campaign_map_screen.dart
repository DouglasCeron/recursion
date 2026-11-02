import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../boss_evolution/application/boss_lineage_controller.dart';
import '../../boss_evolution/domain/boss_lineage.dart';
import '../application/progress_controller.dart';
import '../domain/player_progress.dart';

enum CampaignNodeStatus { locked, available, fought, defeated }

/// One boss on the campaign path.
class CampaignNode {
  const CampaignNode({
    required this.bossId,
    required this.name,
    required this.number,
    required this.status,
  });

  /// Null for the locked boss that does not exist yet.
  final String? bossId;
  final String name;
  final int number;
  final CampaignNodeStatus status;

  bool get isPlayable => status != CampaignNodeStatus.locked;

  /// Every boss of the lineage, then one locked node: the next boss is only
  /// generated once the latest one has been fought.
  static List<CampaignNode> fromProgress(
    PlayerProgress progress,
    BossLineage lineage,
  ) => [
    for (final (index, bossId) in lineage.bossIds.indexed)
      CampaignNode(
        bossId: bossId,
        name: lineage.nameOf(index + 1),
        number: index + 1,
        status: switch (bossId) {
          _ when progress.isBossDefeated(bossId) => CampaignNodeStatus.defeated,
          _ when progress.foughtBossIds.contains(bossId) =>
            CampaignNodeStatus.fought,
          _ => CampaignNodeStatus.available,
        },
      ),
    CampaignNode(
      bossId: null,
      name: '???',
      number: lineage.length + 1,
      status: CampaignNodeStatus.locked,
    ),
  ];
}

/// The campaign as a path of numbered bosses joined by lines.
class CampaignMapScreen extends ConsumerWidget {
  const CampaignMapScreen({required this.onBossSelected, super.key});

  final void Function(String bossId) onBossSelected;

  static const _nodeSize = 64.0;
  static const _rowHeight = 150.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = CampaignNode.fromProgress(
      ref.watch(progressControllerProvider),
      ref.watch(bossLineageControllerProvider),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Campaign')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final centers = [
            for (var i = 0; i < nodes.length; i++)
              Offset(
                width * (i.isEven ? 0.3 : 0.7),
                _rowHeight * i + _nodeSize,
              ),
          ];
          return SingleChildScrollView(
            child: SizedBox(
              width: width,
              height: _rowHeight * nodes.length + _nodeSize,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PathPainter(centers: centers, nodes: nodes),
                    ),
                  ),
                  for (final (i, node) in nodes.indexed)
                    Positioned(
                      left: centers[i].dx - 70,
                      top: centers[i].dy - _nodeSize / 2,
                      width: 140,
                      child: _NodeView(
                        node: node,
                        size: _nodeSize,
                        onTap: switch (node.bossId) {
                          final id? => () => onBossSelected(id),
                          null => null,
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NodeView extends StatelessWidget {
  const _NodeView({required this.node, required this.size, this.onTap});

  final CampaignNode node;
  final double size;
  final VoidCallback? onTap;

  static const _available = Color(0xFF7FD4FF);
  static const _defeated = Color(0xFF7CE38B);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (color, icon, label) = switch (node.status) {
      CampaignNodeStatus.locked => (Colors.white24, Icons.lock, 'Locked'),
      CampaignNodeStatus.available => (_available, null, 'Available'),
      CampaignNodeStatus.fought => (_available, null, 'Not defeated yet'),
      CampaignNodeStatus.defeated => (_defeated, Icons.check, 'Defeated'),
    };
    return Column(
      children: [
        Material(
          key: Key('campaign.node.${node.bossId ?? 'next'}'),
          color: Theme.of(context).scaffoldBackgroundColor,
          shape: CircleBorder(side: BorderSide(color: color, width: 3)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: color)
                    : Text(
                        '${node.number}',
                        style: textTheme.titleLarge?.copyWith(color: color),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('${node.number}. ${node.name}', style: textTheme.titleSmall),
        Text(label, style: textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({required this.centers, required this.nodes});

  final List<Offset> centers;
  final List<CampaignNode> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i + 1 < centers.length; i++) {
      final reached = nodes[i + 1].isPlayable;
      canvas.drawLine(
        centers[i],
        centers[i + 1],
        Paint()
          ..strokeWidth = reached ? 4 : 2
          ..color = reached ? const Color(0xFF7FD4FF) : Colors.white24,
      );
    }
  }

  @override
  bool shouldRepaint(_PathPainter oldDelegate) =>
      oldDelegate.nodes != nodes || oldDelegate.centers != centers;
}
