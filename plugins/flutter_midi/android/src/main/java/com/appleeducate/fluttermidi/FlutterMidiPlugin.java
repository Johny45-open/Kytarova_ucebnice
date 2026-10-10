package com.appleeducate.fluttermidi;

import androidx.annotation.NonNull;
import cn.sherlock.com.sun.media.sound.SF2Soundbank;
import cn.sherlock.com.sun.media.sound.SoftSynthesizer;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import java.io.File;
import java.io.IOException;
import jp.kshoji.javax.sound.midi.InvalidMidiDataException;
import jp.kshoji.javax.sound.midi.MidiUnavailableException;
import jp.kshoji.javax.sound.midi.Receiver;
import jp.kshoji.javax.sound.midi.ShortMessage;

/** FlutterMidiPlugin */
public class FlutterMidiPlugin implements FlutterPlugin, MethodCallHandler {
  private MethodChannel channel;
  private SoftSynthesizer synth;
  private Receiver recv;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    onAttachedToEngine(binding.getBinaryMessenger());
  }

  private void onAttachedToEngine(BinaryMessenger messenger) {
    channel = new MethodChannel(messenger, "flutter_midi");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }
    if (synth != null) {
      try {
        synth.close();
      } catch (Exception ignored) {
      }
      synth = null;
      recv = null;
    }
  }

  /** Plugin registration for v1 embedding was removed - v1 embedding is no longer supported. */

  @Override
  public void onMethodCall(MethodCall call, @NonNull Result result) {
    if (call.method.equals("prepare_midi")) {
      try {
        String _path = call.argument("path");
        File _file = new File(_path);
        SF2Soundbank sf = new SF2Soundbank(_file);
        synth = new SoftSynthesizer();
        synth.open();
        synth.loadAllInstruments(sf);
        synth.getChannels()[0].programChange(0);
        synth.getChannels()[1].programChange(1);
        recv = synth.getReceiver();
        result.success(null);
      } catch (IOException | MidiUnavailableException e) {
        e.printStackTrace();
        result.error("PREPARE_FAILED", e.getMessage(), null);
      }
    } else if (call.method.equals("change_sound")) {
      try {
        String _path = call.argument("path");
        File _file = new File(_path);
        SF2Soundbank sf = new SF2Soundbank(_file);
        synth = new SoftSynthesizer();
        synth.open();
        synth.loadAllInstruments(sf);
        synth.getChannels()[0].programChange(0);
        synth.getChannels()[1].programChange(1);
        recv = synth.getReceiver();
        result.success(null);
      } catch (IOException | MidiUnavailableException e) {
        e.printStackTrace();
        result.error("CHANGE_SOUND_FAILED", e.getMessage(), null);
      }
    } else if (call.method.equals("play_midi_note")) {
      Integer _note = call.argument("note");
      if (recv == null || _note == null) {
        result.error("NOT_READY", "Synthesizer not prepared", null);
        return;
      }
      try {
        ShortMessage msg = new ShortMessage();
        msg.setMessage(ShortMessage.NOTE_ON, 0, _note, 127);
        recv.send(msg, -1);
        result.success(null);
      } catch (InvalidMidiDataException e) {
        e.printStackTrace();
        result.error("PLAY_FAILED", e.getMessage(), null);
      }
    } else if (call.method.equals("stop_midi_note")) {
      Integer _note = call.argument("note");
      if (recv == null || _note == null) {
        result.error("NOT_READY", "Synthesizer not prepared", null);
        return;
      }
      try {
        ShortMessage msg = new ShortMessage();
        msg.setMessage(ShortMessage.NOTE_OFF, 0, _note, 127);
        recv.send(msg, -1);
        result.success(null);
      } catch (InvalidMidiDataException e) {
        e.printStackTrace();
        result.error("STOP_FAILED", e.getMessage(), null);
      }
    } else {
      result.notImplemented();
    }
  }
}
