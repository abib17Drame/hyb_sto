///
//  Generated code. Do not modify.
//  source: transfer.proto
//
// @dart = 2.12
// ignore_for_file: annotate_overrides,camel_case_types,constant_identifier_names,directives_ordering,library_prefixes,non_constant_identifier_names,prefer_final_fields,return_of_invalid_type,unnecessary_const,unnecessary_import,unnecessary_this,unused_import,unused_shown_name

import 'dart:async' as $async;

import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'transfer.pb.dart' as $0;
export 'transfer.pb.dart';

class FileTransferClient extends $grpc.Client {
  static final _$uploadFile = $grpc.ClientMethod<$0.Chunk, $0.UploadStatus>(
      '/transfer.FileTransfer/UploadFile',
      ($0.Chunk value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.UploadStatus.fromBuffer(value));
  static final _$downloadFile = $grpc.ClientMethod<$0.DownloadRequest, $0.Chunk>(
      '/transfer.FileTransfer/DownloadFile',
      ($0.DownloadRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Chunk.fromBuffer(value));

  FileTransferClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options, interceptors: interceptors);

  $grpc.ResponseFuture<$0.UploadStatus> uploadFile(
      $async.Stream<$0.Chunk> request,
      {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$uploadFile, request, options: options).single;
  }

  $grpc.ResponseStream<$0.Chunk> downloadFile($0.DownloadRequest request,
      {$grpc.CallOptions? options}) {
    return $createStreamingCall(
        _$downloadFile, $async.Stream.fromIterable([request]),
        options: options);
  }
}

abstract class FileTransferServiceBase extends $grpc.Service {
  $core.String get $name => 'transfer.FileTransfer';

  FileTransferServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Chunk, $0.UploadStatus>(
        'UploadFile',
        uploadFile,
        true,
        false,
        ($core.List<$core.int> value) => $0.Chunk.fromBuffer(value),
        ($0.UploadStatus value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DownloadRequest, $0.Chunk>(
        'DownloadFile',
        downloadFile_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.DownloadRequest.fromBuffer(value),
        ($0.Chunk value) => value.writeToBuffer()));
  }

  $async.Future<$0.UploadStatus> uploadFile(
      $grpc.ServiceCall call, $async.Stream<$0.Chunk> request);
  $async.Stream<$0.Chunk> downloadFile_Pre($grpc.ServiceCall call,
      $async.Future<$0.DownloadRequest> request) async* {
    yield* downloadFile(call, await request);
  }

  $async.Stream<$0.Chunk> downloadFile(
      $grpc.ServiceCall call, $0.DownloadRequest request);
}
