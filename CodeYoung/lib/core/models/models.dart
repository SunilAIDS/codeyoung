/// Plain data models deserialised from the CodeYoung REST API.
///
/// Kept deliberately dependency-free (no code generation) so the screens can
/// be read top-to-bottom without jumping to `.g.dart` files.
library;

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.bio,
    this.avatarUrl,
    this.isPremium = false,
    this.role = 'student',
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String? bio;
  final String? avatarUrl;
  final bool isPremium;
  final String role;
  final String? createdAt;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? 'CodeYoung Learner'}',
        email: '${j['email'] ?? ''}',
        bio: j['bio'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        isPremium: j['is_premium'] == true || j['is_premium'] == 1,
        role: '${j['role'] ?? 'student'}',
        createdAt: j['created_at'] as String?,
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class Course {
  const Course({
    required this.id,
    required this.slug,
    required this.title,
    this.subtitle,
    this.description,
    required this.category,
    required this.level,
    this.ageGroup,
    this.duration,
    this.price,
    this.imageUrl,
    this.icon,
    this.color,
    this.isFeatured = false,
    this.lessonsCount = 0,
    this.completedCount = 0,
    this.progressPercent = 0,
    this.lessons = const [],
  });

  final int id;
  final String slug;
  final String title;
  final String? subtitle;
  final String? description;
  final String category;
  final String level;
  final String? ageGroup;
  final String? duration;
  final double? price;
  final String? imageUrl;
  final String? icon;
  final String? color;
  final bool isFeatured;
  final int lessonsCount;
  final int completedCount;
  final int progressPercent;
  final List<Lesson> lessons;

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: int.tryParse('${j['id']}') ?? 0,
        slug: '${j['slug'] ?? ''}',
        title: '${j['title'] ?? ''}',
        subtitle: j['subtitle'] as String?,
        description: j['description'] as String?,
        category: '${j['category'] ?? 'Coding'}',
        level: '${j['level'] ?? 'Beginner'}',
        ageGroup: j['age_group'] as String?,
        duration: j['duration'] as String?,
        price: (j['price'] as num?)?.toDouble(),
        imageUrl: j['image_url'] as String?,
        icon: j['icon'] as String?,
        color: j['color'] as String?,
        isFeatured: j['is_featured'] == true || j['is_featured'] == 1,
        lessonsCount: (j['lessons_count'] as num?)?.toInt() ?? 0,
        completedCount: (j['completed_count'] as num?)?.toInt() ?? 0,
        progressPercent: (j['progress_percent'] as num?)?.toInt() ?? 0,
        lessons: j['lessons'] is List
            ? (j['lessons'] as List).map((e) => Lesson.fromJson(e as Map<String, dynamic>)).toList()
            : const [],
      );
}

class Lesson {
  const Lesson({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    required this.category,
    required this.level,
    this.duration,
    this.thumbnailUrl,
    this.videoId,
    this.videoUrl,
    this.videoType = 'youtube',
    this.objectives = const [],
    this.courseTitle,
    this.courseSlug,
    this.courseColor,
    this.percent = 0,
    this.completed = false,
  });

  final int id;
  final int courseId;
  final String title;
  final String? description;
  final String category;
  final String level;
  final String? duration;
  final String? thumbnailUrl;
  final String? videoId;
  final String? videoUrl;
  final String videoType;
  final List<String> objectives;
  final String? courseTitle;
  final String? courseSlug;
  final String? courseColor;
  final int percent;
  final bool completed;

  bool get hasVideo => (videoType == 'youtube' && (videoId?.isNotEmpty ?? false)) ||
      (videoType == 'mp4' && (videoUrl?.isNotEmpty ?? false));

  factory Lesson.fromJson(Map<String, dynamic> j) {
    List<String> objectives = const [];
    final raw = j['objectives'];
    if (raw is List) {
      objectives = raw.map((e) => '$e').toList();
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = Uri.decodeComponent(raw);
        objectives = decoded.contains('[')
            ? (List<dynamic>.from(decoded as Iterable)).map((e) => '$e').toList()
            : [decoded];
      } catch (_) {
        objectives = [raw];
      }
    }

    return Lesson(
      id: int.tryParse('${j['id']}') ?? 0,
      courseId: int.tryParse('${j['course_id']}') ?? 0,
      title: '${j['title'] ?? ''}',
      description: j['description'] as String?,
      category: '${j['category'] ?? 'Beginner'}',
      level: '${j['level'] ?? 'Beginner'}',
      duration: j['duration'] as String?,
      thumbnailUrl: j['thumbnail_url'] as String?,
      videoId: j['video_id'] as String?,
      videoUrl: j['video_url'] as String?,
      videoType: '${j['video_type'] ?? 'youtube'}',
      objectives: objectives,
      courseTitle: j['course_title'] as String?,
      courseSlug: j['course_slug'] as String?,
      courseColor: j['course_color'] as String?,
      percent: (j['percent'] as num?)?.toInt() ?? 0,
      completed: j['completed'] == true || j['completed'] == 1,
    );
  }
}

class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.level,
    this.duration,
    this.thumbnailUrl,
    this.videoId,
    this.videoUrl,
    this.videoType = 'youtube',
    this.views = 0,
    this.isFeatured = false,
  });

  final int id;
  final String title;
  final String? description;
  final String category;
  final String level;
  final String? duration;
  final String? thumbnailUrl;
  final String? videoId;
  final String? videoUrl;
  final String videoType;
  final int views;
  final bool isFeatured;

  /// Resolves a thumbnail for both YouTube and direct MP4 sources.
  String? get thumb {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl;
    if (videoType == 'youtube' && (videoId?.isNotEmpty ?? false)) {
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }
    return null;
  }

  factory VideoItem.fromJson(Map<String, dynamic> j) => VideoItem(
        id: int.tryParse('${j['id']}') ?? 0,
        title: '${j['title'] ?? ''}',
        description: j['description'] as String?,
        category: '${j['category'] ?? 'Beginner'}',
        level: '${j['level'] ?? 'Beginner'}',
        duration: j['duration'] as String?,
        thumbnailUrl: j['thumbnail_url'] as String?,
        videoId: j['video_id'] as String?,
        videoUrl: j['video_url'] as String?,
        videoType: '${j['video_type'] ?? 'youtube'}',
        views: (j['views'] as num?)?.toInt() ?? 0,
        isFeatured: j['is_featured'] == true || j['is_featured'] == 1,
      );

  String get viewsLabel {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M views';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(0)}K views';
    return '$views views';
  }
}

class GalleryImage {
  const GalleryImage({
    required this.id,
    required this.title,
    this.description,
    required this.url,
    required this.category,
  });

  final int id;
  final String title;
  final String? description;
  final String url;
  final String category;

  factory GalleryImage.fromJson(Map<String, dynamic> j) => GalleryImage(
        id: int.tryParse('${j['id']}') ?? 0,
        title: '${j['title'] ?? 'Untitled'}',
        description: j['description'] as String?,
        url: '${j['url'] ?? ''}',
        category: '${j['category'] ?? 'General'}',
      );
}

class PromoBanner {
  const PromoBanner({
    required this.title,
    this.subtitle,
    this.badge,
    this.imageUrl,
    this.gradient,
    this.ctaLabel,
    this.ctaRoute,
  });

  final String title;
  final String? subtitle;
  final String? badge;
  final String? imageUrl;
  final String? gradient;
  final String? ctaLabel;
  final String? ctaRoute;

  factory PromoBanner.fromJson(Map<String, dynamic> j) => PromoBanner(
        title: '${j['title'] ?? ''}',
        subtitle: j['subtitle'] as String?,
        badge: j['badge'] as String?,
        imageUrl: j['image_url'] as String?,
        gradient: j['gradient'] as String?,
        ctaLabel: j['cta_label'] as String?,
        ctaRoute: j['cta_route'] as String?,
      );
}

class Achievement {
  const Achievement({
    required this.title,
    required this.icon,
    this.earned = false,
    this.earnedAt,
  });

  final String title;
  final String icon;
  final bool earned;
  final String? earnedAt;

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        title: '${j['title'] ?? ''}',
        icon: '${j['icon'] ?? 'star'}',
        earned: j['earned'] == true || j['earned'] == 1,
        earnedAt: j['earned_at'] as String?,
      );
}

class UserStats {
  const UserStats({
    this.lessonsCompleted = 0,
    this.hoursLearned = 0,
    this.projectsBuilt = 0,
    this.streak = 0,
    this.level = 1,
    this.achievements = 0,
    this.totalXp = 0,
    this.achievementsList = const [],
  });

  final int lessonsCompleted;
  final int hoursLearned;
  final int projectsBuilt;
  final int streak;
  final int level;
  final int achievements;
  final int totalXp;
  final List<Achievement> achievementsList;

  factory UserStats.fromJson(Map<String, dynamic> j) => UserStats(
        lessonsCompleted: (j['lessonsCompleted'] as num?)?.toInt() ?? 0,
        hoursLearned: (j['hoursLearned'] as num?)?.toInt() ?? 0,
        projectsBuilt: (j['projectsBuilt'] as num?)?.toInt() ?? 0,
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        level: (j['level'] as num?)?.toInt() ?? 1,
        achievements: (j['achievements'] as num?)?.toInt() ?? 0,
        totalXp: (j['totalXp'] as num?)?.toInt() ?? 0,
        achievementsList: j['achievementsList'] is List
            ? (j['achievementsList'] as List)
                .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
                .toList()
            : const [],
      );
}

class Founder {
  const Founder({
    required this.name,
    required this.role,
    required this.almaMater,
    required this.photo,
    required this.quote,
  });

  final String name;
  final String role;
  final String almaMater;
  final String photo;
  final String quote;

  factory Founder.fromJson(Map<String, dynamic> j) => Founder(
        name: '${j['name'] ?? ''}',
        role: '${j['role'] ?? ''}',
        almaMater: '${j['alma_mater'] ?? ''}',
        photo: '${j['photo'] ?? ''}',
        quote: '${j['quote'] ?? ''}',
      );
}

class AboutInfo {
  const AboutInfo({
    required this.company,
    required this.founders,
    required this.advantages,
    required this.awards,
    required this.subjects,
  });

  final Map<String, dynamic> company;
  final List<Founder> founders;
  final List<Map<String, dynamic>> advantages;
  final List<Map<String, dynamic>> awards;
  final List<String> subjects;

  factory AboutInfo.fromJson(Map<String, dynamic> j) => AboutInfo(
        company: j['company'] is Map<String, dynamic>
            ? j['company'] as Map<String, dynamic>
            : const {},
        founders: j['founders'] is List
            ? (j['founders'] as List)
                .map((e) => Founder.fromJson(e as Map<String, dynamic>))
                .toList()
            : const [],
        advantages: j['advantages'] is List
            ? (j['advantages'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
            : const [],
        awards: j['awards'] is List
            ? (j['awards'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
            : const [],
        subjects: j['subjects'] is List
            ? (j['subjects'] as List).map((e) => '$e').toList()
            : const [],
      );
}

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.source,
    this.sources = const [],
    this.audioBase64,
    this.pending = false,
    this.error,
    this.timestamp,
  });

  final String role; // 'user' | 'assistant'
  final String content;
  final String? source;
  final List<Map<String, dynamic>> sources;
  final String? audioBase64;
  final bool pending;
  final String? error;
  final DateTime? timestamp;

  bool get isUser => role == 'user';

  Map<String, dynamic> toHistoryJson() => {'role': role, 'content': content};

  ChatMessage copyWith({bool? pending, String? error, String? audioBase64}) =>
      ChatMessage(
        role: role,
        content: content,
        source: source,
        sources: sources,
        audioBase64: audioBase64 ?? this.audioBase64,
        pending: pending ?? this.pending,
        error: error ?? this.error,
        timestamp: timestamp,
      );
}
