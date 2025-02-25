import 'package:flutter/material.dart';
import 'package:reader/widgets/book_grid.dart';

class LibaryPage extends StatelessWidget {
  const LibaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Book> books = [
      const Book(
        title: '三体',
        coverImage: 'assets/images/book_cover_not_available.jpg',
        progress: 0.3,
      ),
      const Book(
        title: '银河帝国：基地',
        coverImage: 'assets/images/book_cover_not_available.jpg',
        progress: 0.5,
      ),
      const Book(
        title: '沙丘',
        coverImage: 'assets/images/book_cover_not_available.jpg',
        progress: 0.8,
      ),
      const Book(
        title: '神们自己',
        coverImage: 'assets/images/book_cover_not_available.jpg',
        progress: 0.1,
      ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '书库',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              BookGrid(books: books),
            ],
          ),
        ),
      ),
    );
  }}
