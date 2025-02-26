import 'package:flutter/material.dart';
import 'package:reader/services/reading_service.dart';
import 'package:reader/widgets/semi_circle_progress_painter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ReadingService _readingService = ReadingService();
  int _dailyTarget = 40;
  int _dailyReadingTime = 20;
  int _readingStreak = 0;

  @override
  void initState() {
    super.initState();
    _initReadingData();
  }

  Future<void> _initReadingData() async {
    await _readingService.init();
    final dailyTarget = await _readingService.getDailyTarget();
    final dailyReadingTime = await _readingService.getDailyReadingTime();
    final readingStreak = await _readingService.getReadingStreak();

    setState(() {
      _dailyTarget = dailyTarget;
      _dailyReadingTime = dailyReadingTime;
      _readingStreak = readingStreak;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '主页',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            value: _dailyReadingTime / _dailyTarget,
                            strokeWidth: 4,
                            backgroundColor:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _dailyReadingTime.toString(),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                _dailyTarget.toString(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  '阅读目标',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '找一本好书，设定一个目标，养成每天阅读的习惯。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: SizedBox(
                  width: 340,
                  height: 340,
                  child: Stack(
                    children: [
                      Stack(
                        children: [
                          CustomPaint(
                            size: const Size(380, 380),
                            painter: SemiCircleProgressPainter(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceVariant.withOpacity(0.15),
                              progressColor: Theme.of(
                                context,
                              ).colorScheme.surfaceVariant.withOpacity(0.15),
                              strokeWidth: 12,
                              value: 1,
                              strokeCap: StrokeCap.round,
                              strokeAlign: BorderSide.strokeAlignCenter,
                            ),
                          ),
                          CustomPaint(
                            size: const Size(380, 380),
                            painter: SemiCircleProgressPainter(
                              backgroundColor: Color.fromARGB(
                                255,
                                151,
                                120,
                                120,
                              ).withAlpha(22),
                              progressColor: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.9),
                              strokeWidth: 12,
                              value: _dailyReadingTime / _dailyTarget,
                              strokeCap: StrokeCap.round,
                              strokeAlign: BorderSide.strokeAlignCenter,
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '今日阅读进度',
                              style: Theme.of(
                                context,
                              ).textTheme.headlineSmall?.copyWith(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                letterSpacing: 0.5,
                                height: 1.2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_dailyReadingTime}:00',
                              style: Theme.of(context).textTheme.displayLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '(目标 $_dailyTarget 分钟)',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                letterSpacing: 0.5,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDayIndicator(context, '周日', true),
                    _buildDayIndicator(context, '周一', false),
                    _buildDayIndicator(context, '周二', false),
                    _buildDayIndicator(context, '周三', false),
                    _buildDayIndicator(context, '周四', false),
                    _buildDayIndicator(context, '周五', false),
                    _buildDayIndicator(context, '周六', false),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '开启连续阅读新记录',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Text(
                  '你的记录是 $_readingStreak 天。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayIndicator(BuildContext context, String day, bool isActive) {
    return Column(
      children: [
        Text(
          day,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isActive
                        ? Theme.of(context).colorScheme.surface
                        : Theme.of(context).colorScheme.surfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
