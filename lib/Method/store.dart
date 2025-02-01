import 'package:shared_preferences/shared_preferences.dart';

Future<void> storeChildId(String childId) async {
  // Get SharedPreferences instance
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Store the childDocId in SharedPreferences
  await prefs.setString("childDocId", childId);

  // Verify the childDocId is correctly stored by printing it
  print("Child ID stored: ${prefs.getString("childDocId")}");
}
