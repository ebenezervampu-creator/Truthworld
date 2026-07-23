class TopicCategory {

  const TopicCategory({
    required this.id,
    required this.title,
    required this.imageUrl,
  });
  final String id;
  final String title;
  final String imageUrl;
}

class TopicCategoriesConfig {
  static const List<TopicCategory> categories = [
    TopicCategory(
      id: 'all',
      title: 'All',
      imageUrl:
          'https://images.unsplash.com/photo-1541701494587-cb58502866ab?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'gaming',
      title: 'Gaming',
      imageUrl:
          'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'music',
      title: 'Music',
      imageUrl:
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'entertainment',
      title: 'Entertainment',
      imageUrl:
          'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'education',
      title: 'Education',
      imageUrl:
          'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'technology',
      title: 'Technology',
      imageUrl:
          'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'sports',
      title: 'Sports',
      imageUrl:
          'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'news',
      title: 'News',
      imageUrl:
          'https://images.unsplash.com/photo-1504711434969-e33886168f5c?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'lifestyle',
      title: 'Lifestyle',
      imageUrl:
          'https://images.unsplash.com/photo-1511556532299-8f662fc26c06?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'travel',
      title: 'Travel',
      imageUrl:
          'https://images.unsplash.com/photo-1488646953014-85cb44e25828?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'food',
      title: 'Food',
      imageUrl:
          'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'fashion',
      title: 'Fashion',
      imageUrl:
          'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'health',
      title: 'Health',
      imageUrl:
          'https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'business',
      title: 'Business',
      imageUrl:
          'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'comedy',
      title: 'Comedy',
      imageUrl:
          'https://images.unsplash.com/photo-1516280440614-37939bbacd6a?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'science',
      title: 'Science',
      imageUrl:
          'https://images.unsplash.com/photo-1507668077129-56e32842fceb?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'art',
      title: 'Art',
      imageUrl:
          'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'documentary',
      title: 'Documentary',
      imageUrl:
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'animation',
      title: 'Animation',
      imageUrl:
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'automotive',
      title: 'Automotive',
      imageUrl:
          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'pets',
      title: 'Pets & Animals',
      imageUrl:
          'https://images.unsplash.com/photo-1450778869180-41d0601e046e?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'diy',
      title: 'DIY & How-to',
      imageUrl:
          'https://images.unsplash.com/photo-1530124560676-10551fa77c2a?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'fitness',
      title: 'Fitness',
      imageUrl:
          'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'beauty',
      title: 'Beauty',
      imageUrl:
          'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'finance',
      title: 'Finance',
      imageUrl:
          'https://images.unsplash.com/photo-1559526324-4b87b5e36e44?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'history',
      title: 'History',
      imageUrl:
          'https://images.unsplash.com/photo-1447069387593-a5de0862481e?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'nature',
      title: 'Nature',
      imageUrl:
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1200&q=90',
    ),
    TopicCategory(
      id: 'spirituality',
      title: 'Spirituality',
      imageUrl:
          'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?auto=format&fit=crop&w=1200&q=90',
    ),
  ];
}
