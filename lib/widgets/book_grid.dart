import 'dart:io';

import 'package:flutter/material.dart';
import 'package:reader/services/book_service.dart';

class BookGridItem {
  final String title;
  final String coverPath;
  final double progress;

  const BookGridItem({
    required this.title,
    required this.coverPath,
    required this.progress,
  });
}

class BookGrid extends StatelessWidget {
  final List<Book> books;

  const BookGrid({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 20,
        mainAxisSpacing: 28,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child:
                      book.coverPath != null &&
                              File(book.coverPath!).existsSync()
                          ? Image.file(File(book.coverPath!), fit: BoxFit.cover)
                          : Image.asset(
                            'assets/images/book_cover_not_available.jpg',
                            fit: BoxFit.cover,
                          ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              book.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}
