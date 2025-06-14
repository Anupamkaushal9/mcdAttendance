import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isLayoutScreen;
  const GlassAppBar({required this.title, Key? key, required this.isLayoutScreen}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xff111184).withOpacity(0.6),
                const Color(0xff111184).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 0.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 1,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.4),
                blurRadius: 1,
                spreadRadius: 0.5,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: (!isLayoutScreen)?Padding(
              padding: const EdgeInsets.all(8.0), // Adjust padding if necessary.
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context); // To go back to the previous screen.
                },
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.transparent, // Background color of the rounded back button.
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black,width: 0.5)
                  ),
                  padding: const EdgeInsets.all(8), // Padding inside the button.
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.black, // Icon color
                  ),
                ),
              ),
            ):null,
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
            centerTitle: true,
          ),
        ),
      ),
    );
  }
}