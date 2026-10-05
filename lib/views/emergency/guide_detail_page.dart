import 'package:flutter/material.dart';
import '../../models/emergency_guide_model.dart';

class GuideDetailPage extends StatelessWidget {
  final GuideItem guideItem;

  const GuideDetailPage({super.key, required this.guideItem});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(guideItem.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.red[800],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32))
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(guideItem.icon, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    guideItem.content.isNotEmpty ? guideItem.content : guideItem.title, 
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          
          // Steps List
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final step = guideItem.steps[index];
                  return _buildStepCard(context, index + 1, step);
                },
                childCount: guideItem.steps.length,
              ),
            ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 40))
        ],
      ),
    );
  }

  Widget _buildStepCard(BuildContext context, int index, GuideStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4)
          )
        ],
        border: Border(left: BorderSide(color: Colors.red[800]!, width: 4))
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Number Badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Center(child: Text('$index', style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     children: [
                       if (step.icon != null)
                        Padding(padding: const EdgeInsets.only(right: 8), child: Icon(step.icon, size: 18, color: Colors.grey[600])),
                       Expanded(
                         child: Text(
                           step.title, 
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 8),
                   Text(
                     step.description, 
                     style: TextStyle(color: Colors.grey[800], height: 1.5, fontSize: 15)
                   ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
