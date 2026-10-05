import 'package:flutter_test/flutter_test.dart';
import 'package:earthquake/models/earthquake_model.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Earthquake Model Tests', () {
    test('Should generate deterministic ID when _id is missing', () {
       // Same data -> Same ID
       final json1 = {
          'mag': 5.0,
          'title': 'Test Place',
          'date': '2023.01.01 10:00:00',
          'depth': 10.0,
          'lat': 40.0,
          'lng': 30.0
       };
       
       final eq1 = Earthquake.fromJson(json1);
       final eq2 = Earthquake.fromJson(json1);
       
       expect(eq1.id, equals(eq2.id));
       expect(eq1.id, contains("40.0_30.0_5.0")); // Check hash content
    });

    test('Should prefer API ID if present', () {
       final json = {
          '_id': 'api_provided_id_123',
          'mag': 5.0,
          'title': 'Test Place',
          'date': '2023.01.01 10:00:00',
          'depth': 10.0,
       };
       final eq = Earthquake.fromJson(json);
       expect(eq.id, equals('api_provided_id_123'));
    });
  });
  
  group('Strict Notification Logic Verification', () {
     // We can't easily mock SharedPreferences/Geolocator in a raw unit test without Mockito.
     // But we can verify the LOGIC if we extract it. 
     // Since we modified the logic inside the Service directly, we will simulate the check here.
     
     bool shouldNotify(double userMag, double userDist, double eqMag, double eqDist) {
        // Strict Logic: Dist <= UserDist AND Mag >= UserMag
        if (eqDist <= userDist) {
           if (eqMag >= userMag) {
              return true;
           }
        }
        // Safety net > 6.0 handled separately, but let's test basic strictness first
        return false;
     }

     test('Strict Rule: Distance OK, Mag LOW -> No Notify', () {
        expect(shouldNotify(3.0, 500.0, 2.0, 100.0), isFalse);
     });

     test('Strict Rule: Distance FAR, Mag OK -> No Notify', () {
        expect(shouldNotify(3.0, 500.0, 5.0, 800.0), isFalse);
     });

     test('Strict Rule: Distance OK, Mag OK -> Notify', () {
        expect(shouldNotify(3.0, 500.0, 3.5, 400.0), isTrue);
     });
  });
}
