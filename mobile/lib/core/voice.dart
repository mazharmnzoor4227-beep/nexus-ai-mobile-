import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'files.dart';
import 'session.dart';

class Voice extends ChangeNotifier {
  final Session session;
  final stt = SpeechToText();
  final tts = FlutterTts();
  bool active = false,
      muted = false,
      speaker = true,
      ready = false,
      closed = false;
  String state = 'Ready', transcript = '', language = 'en-US';
  double level = 0;
  int epoch = 0;
  Timer? timer;
  DateTime? started;
  Voice(this.session);
  void update() {
    if (!closed) notifyListeners();
  }

  Future<bool> init() async {
    ready = await stt.initialize(
      onStatus: (s) {
        if (s == 'notListening' && active && state == 'Listening') resume();
      },
      onError: (e) {
        state = e.permanent
            ? 'Microphone or speech service unavailable'
            : 'Reconnecting';
        update();
        if (!e.permanent) resume();
      },
    );
    await tts.awaitSpeakCompletion(true);
    return ready;
  }

  Future<void> dictate(void Function(String) onText) async {
    if (!ready && !await init()) {
      state = 'Enable microphone permission and an Android speech service';
      update();
      return;
    }
    if (stt.isListening) {
      await stt.stop();
      return;
    }
    state = 'Listening';
    update();
    await stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: language,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (r) {
        transcript = r.recognizedWords;
        onText(transcript);
        if (r.finalResult) state = 'Ready';
        update();
      },
    );
  }

  Future<void> start() async {
    if (!ready && !await init()) {
      state = 'Speech service unavailable';
      update();
      return;
    }
    active = true;
    muted = false;
    started = DateTime.now();
    epoch++;
    await listen();
  }

  Future<void> listen() async {
    if (!active || muted || session.busy || closed) return;
    state = 'Listening';
    update();
    final current = epoch;
    await stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: language,
        partialResults: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 60),
      ),
      onSoundLevelChange: (v) {
        level = v;
        update();
      },
      onResult: (r) async {
        if (current != epoch || !active || muted) return;
        transcript = r.recognizedWords;
        update();
        if (!r.finalResult || transcript.trim().isEmpty) return;
        timer?.cancel();
        state = 'Thinking';
        update();
        try {
          await stt.stop();
          await session.send(transcript);
          if (current != epoch || !active) return;
          if (session.error.isNotEmpty) {
            state = session.error;
            update();
            return;
          }
          final replies = session.messages.where(
            (m) => m['role'] == 'assistant',
          );
          if (replies.isNotEmpty) {
            transcript = replies.last['text'];
            state = 'Speaking';
            update();
            await tts.setLanguage(language);
            await tts.speak(
              transcript.replaceAll(
                RegExp(r'```[\s\S]*?```'),
                'Code is available in your chat.',
              ),
            );
          }
          if (current == epoch && active && !muted) await listen();
        } catch (_) {
          state = 'Voice connection failed. Tap reconnect.';
          update();
        }
      },
    );
  }

  void resume() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 800), () {
      if (active && !muted && !['Speaking', 'Thinking'].contains(state)) {
        listen();
      }
    });
  }

  Future<void> interrupt() async {
    epoch++;
    timer?.cancel();
    session.stop();
    await stt.cancel();
    await tts.stop();
    while (session.busy && active) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (active && !muted) await listen();
  }

  Future<void> mute() async {
    muted = !muted;
    epoch++;
    timer?.cancel();
    await stt.cancel();
    await tts.stop();
    session.stop();
    state = muted ? 'Muted' : 'Ready';
    update();
    if (!muted) await interrupt();
  }

  Future<void> output() async {
    speaker = !speaker;
    await native.invokeMethod('speaker', {'enabled': speaker});
    update();
  }

  Future<void> end() async {
    active = false;
    epoch++;
    timer?.cancel();
    session.stop();
    await stt.cancel();
    await tts.stop();
    state = 'Ended';
    update();
    await native.invokeMethod('speaker', {'enabled': true, 'end': true});
  }

  @override
  void dispose() {
    closed = true;
    active = false;
    epoch++;
    timer?.cancel();
    stt.cancel();
    tts.stop();
    super.dispose();
  }
}
