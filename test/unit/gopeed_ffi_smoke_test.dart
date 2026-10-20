import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _InvokeResultNative = Void Function(Uint64 requestID, Int32 success, Pointer<Char> payload);

void main() {
  test('Gopeed FFI library can be loaded and Start/InvokeAsync/Stop called', () async {
    final dylibPath = '${Directory.current.path}/macos/Frameworks/libgopeed.dylib';
    expect(File(dylibPath).existsSync(), isTrue);

    final dylib = DynamicLibrary.open(dylibPath);

    final startPtr = dylib.lookup<NativeFunction<StartReturn Function(Pointer<Char>)>>('Start');
    final startFn = startPtr.asFunction<StartReturn Function(Pointer<Char>)>();

    final stopPtr = dylib.lookup<NativeFunction<Void Function()>>('Stop');
    final stopFn = stopPtr.asFunction<void Function()>();

    final freeCStringPtr = dylib.lookup<NativeFunction<Void Function(Pointer<Char>)>>('FreeCString');
    final freeCStringFn = freeCStringPtr.asFunction<void Function(Pointer<Char>)>();

    final invokeAsyncPtr = dylib.lookup<
      NativeFunction<
        Void Function(
          Pointer<Char>,
          Pointer<Char>,
          Pointer<Char>,
          Pointer<Char>,
          UnsignedLongLong,
          UintPtr,
        )
      >
    >('InvokeAsync');
    final invokeAsyncFn = invokeAsyncPtr.asFunction<
      void Function(
        Pointer<Char>,
        Pointer<Char>,
        Pointer<Char>,
        Pointer<Char>,
        int,
        int,
      )
    >();

    // Start with in-memory storage config
    final configMap = {
      'network': 'tcp',
      'address': '127.0.0.1:0',
      'apiEnable': false,
      'storage': 'mem',
      'storageDir': '',
      'refreshInterval': 1000,
    };
    final configStr = jsonEncode(configMap);
    final configPtr = configStr.toNativeUtf8();

    try {
      final res = startFn(configPtr.cast());
      if (res.r1 != nullptr) {
        final err = res.r1.cast<Utf8>().toDartString();
        freeCStringFn(res.r1);
        fail('Gopeed Start returned error: $err');
      }
      expect(res.r0, greaterThanOrEqualTo(0));
    } finally {
      malloc.free(configPtr);
    }

    // Test InvokeAsync: GET /api/v1/tasks
    final completer = Completer<dynamic>();
    final callback = NativeCallable<_InvokeResultNative>.listener((
      int reqId,
      int success,
      Pointer<Char> payload,
    ) {
      if (payload == nullptr) {
        completer.completeError('null payload');
        return;
      }
      try {
        final text = payload.cast<Utf8>().toDartString();
        if (success != 0) {
          completer.complete(jsonDecode(text));
        } else {
          completer.completeError(text);
        }
      } finally {
        freeCStringFn(payload);
      }
    });

    final methodPtr = 'GET'.toNativeUtf8();
    final pathPtr = '/api/v1/tasks'.toNativeUtf8();
    final queryPtr = ''.toNativeUtf8();
    final bodyPtr = ''.toNativeUtf8();

    try {
      invokeAsyncFn(
        methodPtr.cast(),
        pathPtr.cast(),
        queryPtr.cast(),
        bodyPtr.cast(),
        1,
        callback.nativeFunction.address,
      );

      final result = await completer.future.timeout(const Duration(seconds: 5));
      expect(result, isNotNull);
      expect(result['code'], equals(0));
      expect(result['data'], isA<List>());
    } finally {
      malloc.free(methodPtr);
      malloc.free(pathPtr);
      malloc.free(queryPtr);
      malloc.free(bodyPtr);
      callback.close();
      stopFn();
    }
  });
}

final class StartReturn extends Struct {
  @LongLong()
  external int r0;

  external Pointer<Char> r1;
}
