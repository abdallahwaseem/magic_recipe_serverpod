import 'package:magic_recipe_server/server.dart';
import 'package:magic_recipe_server/src/recipes/remove_deleted_recipe_future_call.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_server/serverpod_auth_server.dart';

class AdminEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  @override
  Set<Scope> get requiredScopes => {Scope.admin};

  Future<List<UserInfo>> listUsers(Session session) async {
    final users = await UserInfo.db.find(session);

    return users;
  }

  Future<void> blockUser(Session session, int userId) async {
    await Users.blockUser(session, userId);
  }

  Future<void> unblockUser(Session session, int userId) async {
    await Users.unblockUser(session, userId);
  }

  Future<void> triggerDeletedRecipeCleanup(Session session) async {
    await RemoveDeletedRecipesFutureCall().invoke(session, null);
  }

  Future<void> scheduleDeletedRecipeCleanup(Session session) async {
    await pod.futureCallWithDelay(
      FutureCallNames.rescheduleRemoveDeletedRecipes.name,
      null,
      Duration(seconds: 5),
    );
  }

  Future<void> stopCleanupTask(Session session) async {
    await pod
        .cancelFutureCall(FutureCallNames.rescheduleRemoveDeletedRecipes.name);
  }
}
