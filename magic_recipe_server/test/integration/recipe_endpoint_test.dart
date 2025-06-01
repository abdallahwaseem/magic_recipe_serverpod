import 'package:magic_recipe_server/src/receipes/recipes_endpoint.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given recipe endpoint', (sessionBuilder, endpoints) {
    test(
        'When calling generateRecipe with ingredients, gemini is called with a prompt'
        ' which includes the ingredients', () async {
      generateContent = (_, prompt) {
        return Future.value('Mock recipe');
      };

      String inputPrompt = 'chicken, rice, broccoli';
      final recipe =
          await endpoints.recipes.generateRecipe(sessionBuilder, inputPrompt);
      expect(recipe.text, 'Mock recipe');
      expect(recipe.ingredients, inputPrompt);
    });
  });
}
