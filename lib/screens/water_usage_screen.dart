import 'package:flutter/material.dart';

class WaterUsageScreen extends StatefulWidget {
  const WaterUsageScreen({super.key});

  @override
  State<WaterUsageScreen> createState() => _WaterUsageScreenState();
}

class _WaterUsageScreenState extends State<WaterUsageScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // Example remaining percentage (0.0 = empty, 1.0 = full)
  final double remainingPercent = 0.55;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: remainingPercent).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _tableCell(String text, bool isLabel) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isLabel ? FontWeight.w600 : FontWeight.w400,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String text) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF), // Blue color for all buttons
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Get color based on position
  Color _getCircleColor(double value) {
    if (value < 0.33) return Colors.red;
    if (value < 0.66) return Colors.yellow.shade700;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Water Usage",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          // Background watermark
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 260,
                ),
              ),
            ),
          ),

          // Foreground content
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 15),

                // Table
                Table(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnWidths: const {
                    0: FlexColumnWidth(1.5),
                    1: FlexColumnWidth(1),
                  },
                  children: [
                    TableRow(children: [
                      _tableCell("Total Units Used", true),
                      _tableCell("18.6 m\u00B3", false),
                    ]),
                    TableRow(children: [
                      _tableCell("Average Daily Usage", true),
                      _tableCell("2.7 m\u00B3", false),
                    ]),
                    TableRow(children: [
                      _tableCell("Remaining Units", true),
                      _tableCell("12.58 m\u00B3", false),
                    ]),
                    TableRow(children: [
                      _tableCell("Last Top-Up Date", true),
                      _tableCell("01 Nov 2025", false),
                    ]),
                  ],
                ),

                const SizedBox(height: 30),

                // Progress bar with moving circle
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              double barWidth = constraints.maxWidth;
                              double circlePos = barWidth * _animation.value;
                              Color circleColor =
                                  _getCircleColor(_animation.value);

                              return Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  // Background gradient bar
                                  Container(
                                    height: 16,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.red,
                                          Colors.yellow,
                                          Colors.green
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Animated circle indicator
                                  Positioned(
                                    left: circlePos - 14,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: circleColor,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                circleColor.withOpacity(0.5),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Low", style: TextStyle(fontSize: 13)),
                              Text("Moderate", style: TextStyle(fontSize: 13)),
                              Text("Full", style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                const Text(
                  "You have 12.58 m\u00B3 remaining\nEstimated 4 days left",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 40),

                // Buttons
                _buildButton(context, "Buy Units"),
                const SizedBox(height: 16),
                _buildButton(context, "View Statement"),
                const SizedBox(height: 16),
                _buildButton(context, "Set Usage Alert"),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
