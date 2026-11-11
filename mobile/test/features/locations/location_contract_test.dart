import 'package:controle_acesso/features/locations/location_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validação local espelha o contrato da API', () {
    test('nome precisa ter de 2 a 120 caracteres', () {
      expect(LocationValidation.name(null), 'Informe o nome do local.');
      expect(LocationValidation.name('   '), 'Informe o nome do local.');
      expect(
        LocationValidation.name('A'),
        'O nome deve ter pelo menos 2 caracteres.',
      );
      expect(LocationValidation.name('AB'), isNull);
      expect(LocationValidation.name('A' * 120), isNull);
      expect(
        LocationValidation.name('A' * 121),
        'O nome deve ter até 120 caracteres.',
      );
    });

    test('endereço é opcional e vai até 200 caracteres', () {
      expect(LocationValidation.description(''), isNull);
      expect(LocationValidation.description('A' * 200), isNull);
      expect(
        LocationValidation.description('A' * 201),
        'O endereço deve ter até 200 caracteres.',
      );
    });

    test('latitude aceita -90..90 e vírgula decimal', () {
      expect(LocationValidation.latitude(''), 'Informe a latitude.');
      expect(LocationValidation.latitude('abc'), 'Informe uma latitude válida.');
      expect(LocationValidation.latitude('-90'), isNull);
      expect(LocationValidation.latitude('90'), isNull);
      expect(LocationValidation.latitude('-23,1857'), isNull);
      expect(
        LocationValidation.latitude('-90.1'),
        'A latitude deve ficar entre -90 e 90.',
      );
      expect(
        LocationValidation.latitude('90.1'),
        'A latitude deve ficar entre -90 e 90.',
      );
    });

    test('longitude aceita -180..180', () {
      expect(LocationValidation.longitude(''), 'Informe a longitude.');
      expect(
        LocationValidation.longitude('abc'),
        'Informe uma longitude válida.',
      );
      expect(LocationValidation.longitude('-180'), isNull);
      expect(LocationValidation.longitude('180'), isNull);
      expect(
        LocationValidation.longitude('-180.1'),
        'A longitude deve ficar entre -180 e 180.',
      );
      expect(
        LocationValidation.longitude('180.1'),
        'A longitude deve ficar entre -180 e 180.',
      );
    });

    test('raio é inteiro de 1 a 100 metros', () {
      expect(LocationValidation.radius(''), 'Informe o raio em metros.');
      expect(
        LocationValidation.radius('10.5'),
        'Informe o raio em metros inteiros.',
      );
      expect(LocationValidation.radius('0'), 'O raio deve ficar entre 1 e 100 metros.');
      expect(LocationValidation.radius('1'), isNull);
      expect(LocationValidation.radius('100'), isNull);
      expect(
        LocationValidation.radius('101'),
        'O raio deve ficar entre 1 e 100 metros.',
      );
    });

    test('parse decimal aceita ponto e vírgula', () {
      expect(LocationValidation.parseDecimal('-23,1857'), -23.1857);
      expect(LocationValidation.parseDecimal('-23.1857'), -23.1857);
      expect(LocationValidation.parseDecimal(' -45.8846 '), -45.8846);
      expect(LocationValidation.parseDecimal(''), isNull);
    });
  });

  group('Location.fromJson', () {
    Map<String, dynamic> json({
      Object? description = 'Av. Central, 1200',
      Object? latitude = -23.1857,
      Object? longitude = -45.8846,
      Object? radiusMeters = 100,
      Object? isActive = true,
    }) => {
      'id': 'c1f2a3b4-1111-4222-8333-944455556666',
      'name': 'Edifício Aurora · Recepção',
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'isActive': isActive,
      'createdAt': '2026-11-10T12:00:00.000Z',
      'updatedAt': '2026-11-10T12:00:00.000Z',
    };

    test('lê o local do contrato e normaliza a descrição', () {
      final location = Location.fromJson(
        json(description: '  Av. Central, 1200  '),
      );

      expect(location.name, 'Edifício Aurora · Recepção');
      expect(location.description, 'Av. Central, 1200');
      expect(location.latitude, -23.1857);
      expect(location.longitude, -45.8846);
      expect(location.radiusMeters, 100);
      expect(location.isActive, isTrue);
    });

    test('descrição nula ou vazia vira null', () {
      expect(Location.fromJson(json(description: null)).description, isNull);
      expect(Location.fromJson(json(description: '  ')).description, isNull);
    });

    for (final (nome, payload) in [
      ('descrição com tipo errado', json(description: 12)),
      ('latitude fora do intervalo', json(latitude: 90.1)),
      ('longitude fora do intervalo', json(longitude: -180.1)),
      ('raio abaixo de 1', json(radiusMeters: 0)),
      ('raio acima de 100', json(radiusMeters: 101)),
      ('raio não inteiro', json(radiusMeters: 10.5)),
      ('situação ausente', json(isActive: null)),
    ]) {
      test('$nome sai como FormatException', () {
        expect(
          () => Location.fromJson(payload),
          throwsFormatException,
        );
      });
    }
  });

  group('CreateLocationRequest', () {
    test('limpa os campos e omite a descrição vazia', () {
      final request = CreateLocationRequest(
        name: '  Portaria  ',
        description: '   ',
        latitude: -23.1857,
        longitude: -45.8846,
        radiusMeters: 100,
      );

      expect(request.toJson(), {
        'name': 'Portaria',
        'latitude': -23.1857,
        'longitude': -45.8846,
        'radiusMeters': 100,
      });
    });

    test('inclui a descrição quando informada', () {
      final request = CreateLocationRequest(
        name: 'Portaria',
        description: ' Av. Central, 1200 ',
        latitude: 0,
        longitude: 0,
        radiusMeters: 50,
      );

      expect(request.toJson()['description'], 'Av. Central, 1200');
    });
  });
}
