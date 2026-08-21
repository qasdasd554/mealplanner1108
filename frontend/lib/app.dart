import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/email_verification_screen.dart';
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

  // Globalny klucz nawigatora — potrzebny, żeby ShareIntentHandler mógł
  // otworzyć ekran rozpoznawania przepisu z linku POZA drzewem widgetów
  // (udostępnienie z innej aplikacji może przyjść w dowolnym momencie,
  // nie tylko wtedy, gdy mamy pod ręką zwykły BuildContext).
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Meal Planner Polska',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/verify-email': (context) => const EmailVerificationScreen(),
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
