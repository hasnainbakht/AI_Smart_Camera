import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1228),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          "Pricing",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // 15 Day Trial Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEE0979), Color(0xFFFF6A00)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Text(
                "🔥 15-Day FREE Trial on All Premium Plans!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          _planCard(
            context,
            title: "Free Plan",
            price: "0",
            features: [
              "Basic Camera Controls",
              "Grid Overlay",
              "Standard Quality Export",
              "Limited Editing Tools",
            ],
            gradient: const LinearGradient(
              colors: [Color(0xFF6D6BFF), Color(0xFF8B87FF)],
            ),
          ),

          const SizedBox(height: 25),

          _planCard(
            context,
            title: "Pro Plan",
            price: "7.99",
            tag: "Most Popular",
            features: [
              "Full Manual Controls",
              "AI Guidance",
              "Histogram + Level Tool",
              "Unlimited Exports",
              "Advanced Filters",
            ],
            gradient: const LinearGradient(
              colors: [Color(0xFFFF0080), Color(0xFFFF8C00)],
            ),
          ),

          const SizedBox(height: 25),

          _planCard(
            context,
            title: "Ultra Plan",
            price: "14.99",
            tag: "Best Value",
            features: [
              "Everything in Pro",
              "RAW Capture",
              "Cloud Backup",
              "AI Background Removal",
              "Priority Support",
            ],
            gradient: const LinearGradient(
              colors: [Color(0xFF00F5A0), Color(0xFF00D9F5)],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _planCard(
      BuildContext context, {
        required String title,
        required String price,
        List<String>? features,
        String? tag,
        required Gradient gradient,
      }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          if (tag != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: gradient,
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(height: 12),

          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "\$$price / month",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 20),

          ...?features?.map(
                (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.lightGreenAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  )
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                "Choose Plan",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
