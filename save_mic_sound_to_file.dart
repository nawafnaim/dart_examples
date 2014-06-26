import 'dart:html';
import 'dart:async';
import 'dart:web_audio';
import 'dart:typed_data';

bool recording;
List leftchannel;
List rightchannel;
int recordingLength;
int sampleRate;

void main() {

  leftchannel = [];
  rightchannel = [];
  recordingLength = 0;
  sampleRate = 44100;
  recording = true;
  
  // add stop button
  ButtonElement stopBtn = new ButtonElement()
    ..text = 'Stop'
    ..onClick.listen((_) { 
      
      // stop recording
      recording = false;
      
      // we flat the left and right channels down
      var leftBuffer = mergeBuffers ( leftchannel, recordingLength );
      var rightBuffer = mergeBuffers ( rightchannel, recordingLength );
      // we interleave both channels together
      var interleaved = interleave( leftBuffer, rightBuffer );
      
      // we create our wav file
      var buffer = new Uint8List(44 + interleaved.length * 2);
      ByteData view = new ByteData.view(buffer.buffer);
      
      // RIFF chunk descriptor
      writeUTFBytes(view, 0, 'RIFF');
      view.setUint32(4, 44 + interleaved.length * 2, Endianness.LITTLE_ENDIAN);
      writeUTFBytes(view, 8, 'WAVE');
      
      // FMT sub-chunk
      writeUTFBytes(view, 12, 'fmt ');
      view.setUint32(16, 16, Endianness.LITTLE_ENDIAN);
      view.setUint16(20, 1, Endianness.LITTLE_ENDIAN);
      
      // stereo (2 channels)
      view.setUint16(22, 2, Endianness.LITTLE_ENDIAN);
      view.setUint32(24, sampleRate, Endianness.LITTLE_ENDIAN);
      view.setUint32(28, sampleRate * 4, Endianness.LITTLE_ENDIAN);
      view.setUint16(32, 4, Endianness.LITTLE_ENDIAN);
      view.setUint16(34, 16, Endianness.LITTLE_ENDIAN);
      
      // data sub-chunk
      writeUTFBytes(view, 36, 'data');
      view.setUint32(40, interleaved.length * 2, Endianness.LITTLE_ENDIAN);
      
      // write the PCM samples
      var lng = interleaved.length;
      var index = 44;
      var volume = 1;
      for (var i = 0; i < lng; i++){
        view.setInt16(index, (interleaved[i] * (0x7FFF * volume)).truncate(), Endianness.LITTLE_ENDIAN);
        index += 2;
      }
      
      // our final binary blob
      var blob = new Blob ( [ view ] , 'audio/wav'  );
      
      // let's save it locally
      String url = Url.createObjectUrlFromBlob(blob);
      AnchorElement link = new AnchorElement()
      ..href = url
      ..text = 'download'
      ..download = 'output.wav';
      document.body.append(link);
      
    });
  
  document.body.append(stopBtn);
  
  window.navigator.getUserMedia(audio: true).then((MediaStream stream) {
    var context = new AudioContext();
    GainNode volume = context.createGain();
    MediaStreamAudioSourceNode audioInput = context.createMediaStreamSource(stream);
    audioInput.connectNode(volume);
  
    int bufferSize = 2048;
    ScriptProcessorNode recorder = context.createJavaScriptNode(bufferSize, 2, 2);
  
    recorder.onAudioProcess.listen((AudioProcessingEvent e) {
      if (!recording) return;
      print('recording');
      var left = e.inputBuffer.getChannelData(0);
      var right = e.inputBuffer.getChannelData(1);
      print(left);
      
      // process Data
      leftchannel.add(new Float32List.fromList(left));
      rightchannel.add(new Float32List.fromList(right));
      recordingLength += bufferSize;
      
    });
  
    volume.connectNode(recorder);
    recorder.connectNode(context.destination);
  
  });

}

void writeUTFBytes(ByteData view, offset, String string){ 
  var lng = string.length;
  for (var i = 0; i < lng; i++){
    view.setUint8(offset + i, string.codeUnitAt(i));
  }
}

Float32List interleave(leftChannel, rightChannel){
  var length = leftChannel.length + rightChannel.length;
  var result = new Float32List(length);

  var inputIndex = 0;

  for (var index = 0; index < length; ){
    result[index++] = leftChannel[inputIndex];
    result[index++] = rightChannel[inputIndex];
    inputIndex++;
  }
  return result;
}

List mergeBuffers(channelBuffer, recordingLength){
  List result = new List();
  var offset = 0;
  var lng = channelBuffer.length;
  for (var i = 0; i < lng; i++){
    var buffer = channelBuffer[i];
    result.addAll(buffer);
  }
  return result;
}
