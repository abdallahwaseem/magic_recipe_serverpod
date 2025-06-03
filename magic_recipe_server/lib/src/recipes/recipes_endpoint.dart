import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:magic_recipe_server/src/generated/protocol.dart';
import 'package:meta/meta.dart';
import 'package:serverpod/serverpod.dart';

@visibleForTesting
var generateContent =
    (String apiKey, String prompt) async => (await GenerativeModel(
          model: 'gemini-1.5-flash-latest',
          apiKey: apiKey,
        ).generateContent([Content.text(prompt)]))
            .text;

class RecipesEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<Recipe> generateRecipe(Session session, String ingredients) async {
    // Serverpod automatically loads your passwords.yaml file and makes the passwords available
    // in the session.passwords map.
    final geminiApiKey = session.passwords['gemini'];
    if (geminiApiKey == null) {
      throw Exception('Gemini API key not found');
    }

    final cacheKey = 'recipe-${ingredients.hashCode}';
    final cachedRecipe = await session.caches.local.get<Recipe>(cacheKey);

    if (cachedRecipe != null) {
      final userId = (await session.authenticated)?.userId;
      session.log('Recipe found in cache for ingredients: $ingredients');
      final cachedRecipeWithId = await Recipe.db
          .insertRow(session, cachedRecipe.copyWith(userId: userId));
      return cachedRecipeWithId;
    }

    // A prompt to generate a recipe, the user will provide a free text input with the ingredients
    final prompt =
        'Generate a recipe using the following ingredients: $ingredients, always put the title '
        'of the recipe in the first line, and then the instructions. The recipe should be easy '
        'to follow and include all necessary steps. Please provide a detailed recipe.';

    final responseText = await generateContent(geminiApiKey, prompt);

    // Check if the response is empty or null
    if (responseText == null || responseText.isEmpty) {
      throw Exception('No response from Gemini API');
    }

    final userId = (await session.authenticated)?.userId;
    Recipe recipe = Recipe(
      author: 'Gemini',
      text: responseText,
      date: DateTime.now(),
      ingredients: ingredients,
    );
    await session.caches.local
        .put(cacheKey, recipe, lifetime: const Duration(days: 1));

    final recipeWithId =
        await Recipe.db.insertRow(session, recipe.copyWith(userId: userId));

    return recipeWithId;
  }

  Future<List<Recipe>> getRecipes(Session session) async {
    final userId = (await session.authenticated)?.userId;
    final recipes = await Recipe.db.find(session,
        where: (t) => t.deletedAt.equals(null) & t.userId.equals(userId),
        orderBy: (t) => t.date,
        orderDescending: true);
    return recipes;
  }

  Future<void> deleteRecipe(Session session, int recipeId) async {
    final userId = (await session.authenticated)?.userId;
    final recipe = await Recipe.db.findById(session, recipeId);
    if (recipe == null || recipe.userId != userId) {
      throw Exception('Recipe not found');
    }
    recipe.deletedAt = DateTime.now();
    await Recipe.db.updateRow(session, recipe);
  }
}
