import 'package:flutter/material.dart';

class ThinkingProcessWidget extends StatefulWidget {
  final String? content;
  final int? timeMs;
  final bool isFinished;

  const ThinkingProcessWidget({
    Key? key,
    this.content,
    this.timeMs,
    this.isFinished = false,
  }) : super(key: key);

  @override
  _ThinkingProcessWidgetState createState() => _ThinkingProcessWidgetState();
}

class _ThinkingProcessWidgetState extends State<ThinkingProcessWidget> with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  late AnimationController _controller;
  late Animation<double> _iconTurns;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _iconTurns = Tween<double>(begin: 0.0, end: 0.25).animate(_controller);
    
    if (_isExpanded) {
      _controller.value = 1.0; // Expanded by default
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.content == null || widget.content!.isEmpty) {
      return SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Calculate time string
    String timeStr = '';
    if (widget.timeMs != null) {
      if (widget.timeMs! > 1000) {
        timeStr = '${(widget.timeMs! / 1000).toStringAsFixed(1)}s';
      } else {
        timeStr = '${widget.timeMs}ms';
      }
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(8),
              bottom: _isExpanded ? Radius.zero : Radius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  RotationTransition(
                    turns: _iconTurns,
                    child: Icon(
                      Icons.keyboard_arrow_right,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Thinking Process',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                  Spacer(),
                  if (!widget.isFinished)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),
          // Content
          AnimatedCrossFade(
            firstChild: Container(height: 0), // Collapsed
            secondChild: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                 border: Border(top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!))
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      SizedBox(height: 8),
                      SelectableText(
                        widget.content!,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                  ]
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
