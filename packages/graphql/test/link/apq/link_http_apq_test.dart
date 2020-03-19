import "dart:async";
import "dart:convert";

import 'package:gql/language.dart';
import 'package:graphql/client.dart';
import 'package:graphql/internal.dart';
import 'package:graphql/src/link/apq/link_persisted_queries.dart';
import 'package:graphql/src/link/http/link_http.dart';
import 'package:graphql/src/link/link.dart';
import 'package:graphql/src/link/operation.dart';
import "package:http/http.dart" as http;
import "package:mockito/mockito.dart";
import "package:test/test.dart";

class MockClient extends Mock implements http.Client {}

void main() {
  group('Automatic Persisted Queries link', () {
    MockClient client;
    Operation query;
    Link link;

    setUp(() {
      client = MockClient();
      query = Operation(
        documentNode: parseString('query Operation {}'),
        operationName: 'Operation',
        extensions: {},
      );
      link = PersistedQueriesLink(
        useGETForHashedQueries: true,
      ).concat(
        HttpLink(
          uri: '/graphql-apq-test',
          httpClient: client,
        ),
      );
    });

    test('request persisted query', () async {
      when(
        client.send(any),
      ).thenAnswer(
        (_) => Future.value(
          http.StreamedResponse(
            Stream.fromIterable(
              [utf8.encode('{"data":{}}')],
            ),
            200,
          ),
        ),
      );

      await execute(
        link: link,
        operation: query,
      ).first;

      final http.Request captured = verify(
        client.send(captureAny),
      ).captured.single;

      final extensions = json.decode(captured.url.queryParameters['extensions']);

      expect(
        captured.url,
        Uri.parse('/graphql-apq-test?operationName=Operation&variables=%7B%7D&extensions=%7B%22persistedQuery%22%3A%7B%22sha256Hash%22%3A%228c4ae5b728c7cd94514caf043b362244c226a39dc29517ddbfb9a827abd2faa5%22%2C%22version%22%3A1%7D%7D'),
      );
      expect(
        extensions['persistedQuery']['sha256Hash'],
        '8c4ae5b728c7cd94514caf043b362244c226a39dc29517ddbfb9a827abd2faa5',
      );
      expect(
        captured.method,
        'GET',
      );
      expect(
        captured.headers,
        equals({
          'accept': '*/*',
          'content-type': 'application/json',
        }),
      );
      expect(
        captured.body,
        '',
      );
    });

    test('handle "PERSISTED_QUERY_NOT_FOUND"', () async {
      int count = 0;
      when(
        client.send(any),
      )..thenAnswer(
        (_) {
          count++;
          return Future.value(
            http.StreamedResponse(
              Stream.fromIterable(
                [utf8.encode(count == 1
                  ? '{"errors":[{"extensions": { "code": "PERSISTED_QUERY_NOT_FOUND" }, "message": "PersistedQueryNotFound" }]}'
                  : '{"data":{}}'
                )],
              ),
              200,
            ),
          );
        },
      );

      final result = await execute(
        link: link,
        operation: query,
      ).first;

      final captured = List<http.Request>.from(
        verify(
          client.send(captureAny),
        ).captured
      );

      final extensions = json.decode(captured.first.url.queryParameters['extensions']);
      final postBody = json.decode(captured[1].body);

      expect(
        captured.length,
        2,
      );
      expect(
        captured.first.method,
        'GET',
      );
      expect(
        extensions['persistedQuery']['sha256Hash'],
        '8c4ae5b728c7cd94514caf043b362244c226a39dc29517ddbfb9a827abd2faa5',
      );
      expect(
        captured.first.url,
        Uri.parse('/graphql-apq-test?operationName=Operation&variables=%7B%7D&extensions=%7B%22persistedQuery%22%3A%7B%22sha256Hash%22%3A%228c4ae5b728c7cd94514caf043b362244c226a39dc29517ddbfb9a827abd2faa5%22%2C%22version%22%3A1%7D%7D'),
      );
      expect(
        captured[1].method,
        'POST',
      );
      expect(
        postBody['extensions']['persistedQuery']['sha256Hash'],
        '8c4ae5b728c7cd94514caf043b362244c226a39dc29517ddbfb9a827abd2faa5',
      );
      expect(
        postBody.containsKey('query'),
        isTrue,
      );
      expect(
        result.statusCode,
        200,
      );
    });

    test('handle server that does not support persisted queries', () async {
      int count = 0;
      when(
        client.send(any),
      )..thenAnswer(
        (_) {
          count++;
          return Future.value(
            http.StreamedResponse(
              Stream.fromIterable(
                [utf8.encode(count == 1
                  ? '{"errors":[{"extensions": { "code": "PERSISTED_QUERY_NOT_SUPPORTED" }, "message": "PersistedQueryNotSupported" }]}'
                  : '{"data":{}}'
                )],
              ),
              200,
            ),
          );
        },
      );

      final result = await execute(
        link: link,
        operation: query,
      ).first;

      final captured = List<http.Request>.from(
        verify(
          client.send(captureAny),
        ).captured
      );

      final extensions = json.decode(captured.first.url.queryParameters['extensions']);
      final postBody = json.decode(captured[1].body);

      expect(
        captured.length,
        2,
      );
      expect(
        captured.first.method,
        'GET',
      );
      expect(
        extensions['persistedQuery']['sha256Hash'],
        '8c4ae5b728c7cd94514caf043b362244c226a39dc29517ddbfb9a827abd2faa5',
      );
      expect(
        captured.first.url,
        Uri.parse('/graphql-apq-test?operationName=Operation&variables=%7B%7D&extensions=%7B%22persistedQuery%22%3A%7B%22sha256Hash%22%3A%228c4ae5b728c7cd94514caf043b362244c226a39dc29517ddbfb9a827abd2faa5%22%2C%22version%22%3A1%7D%7D'),
      );
      expect(
        captured[1].method,
        'POST',
      );
      expect(
        postBody.containsKey('extensions'),
        isFalse,
      );
      expect(
        postBody.containsKey('query'),
        isTrue,
      );
      expect(
        result.statusCode,
        200,
      );
    });
  });
}
