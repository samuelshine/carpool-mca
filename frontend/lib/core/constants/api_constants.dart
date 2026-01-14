class ApiConstants {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS Simulator
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1'; 
  
  static const String login = '/login/access-token';
  static const String register = '/users/';
  static const String me = '/users/me';
  
  static const String rides = '/rides/';
  static const String searchRides = '/rides/search';
}
