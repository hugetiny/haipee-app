import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/providers/riverpod_compat.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';

/// Provider for DLNA device list in remote play dialog
final dlnaDeviceListProvider =
    StateProvider.autoDispose<List<Widget>>((ref) => []);

class RemotePlay {
  Future<void> castVideo(String video, String referer) async {
    final searcher = DLNAManager();
    final dlna = await searcher.start();
    await KazumiDialog.show(builder: (BuildContext context) {
      return Consumer(builder: (dialogContext, ref, child) {
        final remoteTexts = dialogContext.t.playback.remote;
        final closeLabel = dialogContext.t.app.cancel;
        final searchLabel = dialogContext.t.navigation.actions.search;
        final dlnaDevices = ref.watch(dlnaDeviceListProvider);

        return AlertDialog(
          title: Text(remoteTexts.title),
          content: SingleChildScrollView(
            child: Column(
              children: dlnaDevices,
            ),
          ),
          actions: [
            const SizedBox(width: 20),
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
              },
              child: Text(
                closeLabel,
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.outline,
                ),
              ),
            ),
            TextButton(
                onPressed: () {
                  ref.read(dlnaDeviceListProvider.notifier).state = [];
                  KazumiDialog.showToast(
                    message: remoteTexts.toast.searching,
                  );
                  dlna.devices.stream.listen((deviceList) {
                    final devices = <Widget>[];
                    deviceList.forEach((key, value) async {
                      debugPrint('Key: $key');
                      debugPrint(
                          'Value: ${value.info.friendlyName} ${value.info.deviceType} ${value.info.URLBase}');
                      devices.add(ListTile(
                          leading: _deviceUPnPIcon(
                              value.info.deviceType.split(':')[3]),
                          title: Text(value.info.friendlyName),
                          subtitle: Text(value.info.deviceType.split(':')[3]),
                          onTap: () {
                            try {
                              KazumiDialog.showToast(
                                message: remoteTexts.toast.casting.replaceFirst(
                                  '{device}',
                                  value.info.friendlyName,
                                ),
                              );
                              DLNADevice(value.info).setUrl(video);
                              DLNADevice(value.info).play();
                            } catch (e) {
                              KazumiLogger().log(Level.error, 'DLNA Error: $e');
                              KazumiDialog.showToast(
                                message: remoteTexts.toast.error.replaceFirst(
                                  '{details}',
                                  e.toString(),
                                ),
                              );
                            }
                          }));
                      ref.read(dlnaDeviceListProvider.notifier).state = devices;
                    });
                  });
                },
                child: Text(
                  searchLabel,
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.outline,
                  ),
                )),
          ],
        );
      });
    }, onDismiss: () {
      searcher.stop();
    });
  }

  Icon _deviceUPnPIcon(String deviceType) {
    switch (deviceType) {
      case 'MediaRenderer':
        return const Icon(Icons.cast_connected);
      case 'MediaServer':
        return const Icon(Icons.cast_connected);
      case 'InternetGatewayDevice':
        return const Icon(Icons.router);
      case 'BasicDevice':
        return const Icon(Icons.device_hub);
      case 'DimmableLight':
        return const Icon(Icons.lightbulb);
      case 'WLANAccessPoint':
        return const Icon(Icons.lan);
      case 'WLANConnectionDevice':
        return const Icon(Icons.wifi_tethering);
      case 'Printer':
        return const Icon(Icons.print);
      case 'Scanner':
        return const Icon(Icons.scanner);
      case 'DigitalSecurityCamera':
        return const Icon(Icons.camera_enhance_outlined);
      default:
        return const Icon(Icons.question_mark);
    }
  }
}
