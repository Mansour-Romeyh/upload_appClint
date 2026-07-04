import 'package:flutter/material.dart';

/// Shows a modern animated bottom sheet with drag handle, scrollable content,
/// a close button, and staggered form field entrance.
Future<T?> showAnimatedBottomSheet<T>({
  required BuildContext context,
  required List<Widget> children,
  String? title,
  String? subtitle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _AnimatedSheetContent(
            title: title,
            subtitle: subtitle,
            scrollController: scrollController,
            children: children,
          );
        },
      );
    },
  );
}

class _AnimatedSheetContent extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final ScrollController scrollController;

  const _AnimatedSheetContent({
    this.title,
    this.subtitle,
    required this.children,
    required this.scrollController,
  });

  @override
  State<_AnimatedSheetContent> createState() => _AnimatedSheetContentState();
}

class _AnimatedSheetContentState extends State<_AnimatedSheetContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 400 + widget.children.length * 50),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = widget.children.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle + close button row
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      tooltip: 'إغلاق',
                      icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.opaque,
                child: SingleChildScrollView(
                  controller: widget.scrollController,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.title != null) ...[
                        _StaggeredItem(
                          animation: _controller,
                          index: 0,
                          totalItems: totalItems + 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title!,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.subtitle!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF353535),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      ...List.generate(totalItems, (index) {
                        return _StaggeredItem(
                          animation: _controller,
                          index: index + 1,
                          totalItems: totalItems + 1,
                          child: widget.children[index],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaggeredItem extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final int totalItems;
  final Widget child;

  const _StaggeredItem({
    required this.animation,
    required this.index,
    required this.totalItems,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final startInterval = (index * 0.08).clamp(0.0, 0.6);
    final endInterval = (startInterval + 0.4).clamp(0.0, 1.0);

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(startInterval, endInterval, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: curvedAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - curvedAnimation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
