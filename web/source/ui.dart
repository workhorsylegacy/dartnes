/*
DartNES Copyright (c) 2013 Matthew Brennan Jones <mattjones@workhorsy.org>
JSNes Copyright (C) 2010 Ben Firshman
vNES Copyright (C) 2006-2011 Jamie Sanders

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

library dartnes;
import 'dart:html';

import 'nes.dart';

class JSNES_DummyUI {
  JSNES_NES nes = null;
  
  JSNES_DummyUI(JSNES_NES nes) {
    this.nes = nes;
  }
 
  void enable() {}
  void updateStatus(String s) {}
  void writeAudio(samples) {}
  void writeFrame(List<int> buffer, List<int> prevBuffer) {}
}

class JSNES_UI {
  JSNES_NES nes = null;
  Element status = null;
  Element parent = null;
  CanvasElement screen = null;
  CanvasRenderingContext2D canvasContext = null;
  ImageData canvasImageData = null;
  SelectElement romSelect = null;
  Map<String, ButtonElement> buttons = null;
  bool zoomed = false;
  var dynamicaudio = null;
  
  JSNES_UI(JSNES_NES nes) {
      assert(nes is JSNES_NES);
                this.nes = nes;

                this.status = query('#status');
                this.parent = query('#emulator');
                
                /*
                 * Screen
                 */
                this.screen = query('#screen');
/*                
                if(this.screen.context2D == null) {
                    this.parent.innerHtml = "Your browser doesn't support the <code>&lt;canvas&gt;</code> tag. Try Google Chrome, Safari, Opera or Firefox!";
                    return;
                }
*/                
                /*
                 * Canvas
                 */
                this.canvasContext = this.screen.context2D;
/*                
                if (!this.canvasContext.getImageData) {
                    this.parent.innerHtml = "Your browser doesn't support writing pixels directly to the <code>&lt;canvas&gt;</code> tag. Try the latest versions of Google Chrome, Safari, Opera or Firefox!";
                    return;
                }
*/                
                this.canvasImageData = this.canvasContext.getImageData(0, 0, 256, 240);
                this.resetCanvas();
                
                /*
                 * ROM loading
                 */
                this.romSelect = query('#romSelect');
                this.romSelect.onChange.listen((event) {
                    this.loadROM();
                });
                
                /*
                 * Buttons
                 */
                this.buttons = {
                    'pause': query('#pause'),
                    'restart': query('#restart'),
                    'sound': query('#sound'),
                    'zoom': query('#zoom')
                };

                this.buttons['pause'].onClick.listen((event) {
                    if (this.nes.isRunning) {
                        this.nes.stop();
                        this.updateStatus("Paused");
                        this.buttons['pause'].text = "resume";
                    }
                    else {
                        this.nes.start();
                        this.buttons['pause'].text = "pause";
                    }
                });
        
                this.buttons['restart'].onClick.listen((event) {
                    this.nes.reloadRom();
                    this.nes.start();
                });
        
                this.buttons['sound'].onClick.listen((event) {
                    if (this.nes.opts['emulateSound']) {
                        this.nes.opts['emulateSound'] = false;
                        this.buttons['sound'].text = "enable sound";
                    }
                    else {
                        this.nes.opts['emulateSound'] = true;
                        this.buttons['sound'].text = "disable sound";
                    }
                });
        
                this.zoomed = false;
                this.buttons['zoom'].onClick.listen((event) {
                    if (this.zoomed) {
                      this.screen.width = 256;
                      this.screen.height = 240;
                        this.buttons['zoom'].text = "zoom in";
                        this.zoomed = false;
                    }
                    else {
                      this.screen.width = 256 * 2;
                      this.screen.height = 240 * 2;
                        this.buttons['zoom'].text = "zoom out";
                        this.zoomed = true;
                    }
                });
            
                /*
                 * Keyboard
                 */
                document.onKeyDown.listen((evt) {
                  this.nes.keyboard.keyDown(evt);
                });
                document.onKeyUp.listen((evt) {
                  this.nes.keyboard.keyUp(evt);
                });
                document.onKeyPress.listen((evt) {
                  this.nes.keyboard.keyPress(evt);
                });
            
                /*
                 * Sound
                 */
//                this.dynamicaudio = new DynamicAudio({
//                    'swf': nes.opts.swfPath + 'dynamicaudio.swf'
//                });
            }

                void loadROM() {
                    this.updateStatus("Downloading...");
                    String url = this.romSelect.value;
                    HttpRequest request = new HttpRequest();
                    request.overrideMimeType('text/plain; charset=x-user-defined');
                    request.onReadyStateChange.listen((_) {
                      if (request.readyState == HttpRequest.DONE &&
                          (request.status == 200 || request.status == 0)) {
                        if(this.nes.loadRom(request.responseText)){
                            this.nes.start();
                            this.enable();
                        }
                      }
                    });
                    request.open('GET', url);
                    request.send();
                }
                
                void resetCanvas() {
                    this.canvasContext.fillStyle = 'black';
                    // set alpha to opaque
                    this.canvasContext.fillRect(0, 0, 256, 240);

                    // Set alpha
                    for (int i = 3; i < this.canvasImageData.data.length-3; i += 4) {
                        this.canvasImageData.data[i] = 0xFF;
                    }
                }
                
                /*
                 * Enable and reset UI elements
                 */
                void enable() {
                    this.buttons['pause'].disabled = false;
                    if (this.nes.isRunning) {
                        this.buttons['pause'].text = "pause";
                    }
                    else {
                        this.buttons['pause'].text = "resume";
                    }
                    this.buttons['restart'].disabled = false;
                    if (this.nes.opts['emulateSound']) {
                        this.buttons['sound'].text = "disable sound";
                    }
                    else {
                        this.buttons['sound'].text = "enable sound";
                    }
                }
            
                void updateStatus(String s) {
                    this.status.text = s;
                }
            
//                void writeAudio(samples) {
//                    return this.dynamicaudio.writeInt(samples);
//                }
            
                void writeFrame(List<int> buffer, List<int> prevBuffer) {
                    List<int> imageData = this.canvasImageData.data;
                    int pixel, i, j;

                    for (i=0; i<256*240; i++) {
                        pixel = buffer[i];

                        if (pixel != prevBuffer[i]) {
                            j = i*4;
                            imageData[j] = pixel & 0xFF;
                            imageData[j+1] = (pixel >> 8) & 0xFF;
                            imageData[j+2] = (pixel >> 16) & 0xFF;
                            prevBuffer[i] = pixel;
                        }
                    }

                    this.canvasContext.putImageData(this.canvasImageData, 0, 0);
                }
            }

