import 'package:aiapp/pallete.dart';
import 'package:flutter/material.dart';

class FeatureBox extends StatelessWidget {
  final Color color;
  final String headerText;
  final String descriptionText;
  final VoidCallback? onTap;

  const FeatureBox({
    super.key,
    required this.color,
    required this.headerText,
    required this.descriptionText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Material(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerText,
                  style: const TextStyle(
                    fontFamily: 'Cera Pro',
                    color: Pallete.blackColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  descriptionText,
                  style: const TextStyle(fontFamily: 'Cera Pro', color: Pallete.blackColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
