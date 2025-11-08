import 'package:zoom/zoom.dart';
import 'package:zoom/zoom_options.dart';

final _zoom = Zoom();

Future<bool> initZoomSdk({
  required String domain,
  String? appKey,
  String? appSecret,
  String? jwtToken,
}) async {
  final options = ZoomOptions(
    domain: domain,
    appKey: appKey,
    appSecret: appSecret,
    jwtToken: jwtToken,
  );

  final result = await _zoom.init(options);
  return result.isNotEmpty && result[0] == 0;
}

Future<bool> joinMeeting({
  required String meetingId,
  required String password,
  required String userId,
}) async {
  final meetingOptions = ZoomMeetingOptions(
    userId: userId,
    meetingId: meetingId,
    meetingPassword: password,
    displayName: userId,
    disableDialIn: '0',
    disableDrive: '0',
    disableInvite: '0',
    disableShare: '0',
    noDisconnectAudio: '0',
    noAudio: '0',
  );

  return await _zoom.joinMeeting(meetingOptions);
}

Future<bool> startMeeting({
  required String meetingId,
  required String password,
  required String userId,
  required String displayName,
  required String zoomAccessToken,
}) async {
  final meetingOptions = ZoomMeetingOptions(
    userId: userId,
    meetingId: meetingId,
    meetingPassword: password,
    displayName: displayName,
    zoomAccessToken: zoomAccessToken,
    disableDialIn: '0',
    disableDrive: '0',
    disableInvite: '0',
    disableShare: '0',
    noDisconnectAudio: '0',
    noAudio: '0',
  );
  return await _zoom.startMeeting(meetingOptions);
}