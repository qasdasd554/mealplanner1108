import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/meal_plan/plan_config_screen.dart';
import 'screens/meal_plan/plan_view_screen.dart';
import 'screens/shopping/shopping_list_screen.dart';
import 'screens/recipes/recipes_screen.dart';
import 'screens/recipes/recipe_detail_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/tracker/calorie_tracker_screen.dart';
import 'screens/tracker/add_food_entry_screen.dart';
import 'screens/promotions/promotions_screen.dart';

class SmartMealPlannerApp extends StatelessWidget {
  const SmartMealPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Smart Meal Planner PL',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/home': (context) => const HomeScreen(),
            '/plan/config': (context) => const PlanConfigScreen(),
            '/plan/view': (context) => const PlanViewScreen(),
            '/shopping': (context) => const ShoppingListScreen(),
            '/recipes': (context) => const RecipesScreen(),
            '/recipe/detail': (context) => const RecipeDetailScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/products': (context) => const ProductsScreen(),
            '/tracker': (context) => const CalorieTrackerScreen(),
            '/tracker/add': (context) => const AddFoodEntryScreen(),
            '/promotions': (context) => const PromotionsScreen(),
          },
        );
      },
    );
  }
}
