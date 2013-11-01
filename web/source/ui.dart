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

library dartnes_ui;
import 'dart:html';
//import 'dart:web_audio';

import 'nes.dart';

// Returns true if running in JavaScript
// It works because JS uses doubles for integers
// Therefore in JS a 1 is the same as 1.0
bool is_running_in_js() {
    return identical(1, 1.0);
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
  
  JSNES_UI() {
                // Tell the user if we are running in Dart or JS
                Element vm = query('#vm');
                if(is_running_in_js()) {
                  vm.innerHtml = "Using JavaScript VM";
                } else {
                  vm.innerHtml = "Using Dart VM";
                }
    
                this.status = query('#status');
                this.parent = query('#emulator');
    
                void status_cb(String m) => updateStatus(m);
                void frame_cb(List<int> bytes) => writeFrame(bytes);
                void audio_cb(List<int> samples) => writeAudio(samples);
                this.nes = new JSNES_NES(status_cb, frame_cb, audio_cb);
                
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
            }

                void loadROM() {
                    this.updateStatus("Downloading...");
                    String url = this.romSelect.value;
                    HttpRequest request = new HttpRequest();
                    request.overrideMimeType('text/plain; charset=x-user-defined');
                    request.onReadyStateChange.listen((_) {
                      // Just return if not done yet
                      if(request.readyState != HttpRequest.DONE)
                        return;
                      
                      // Load the rom on success
                      if (request.status == 200) {
                        if(this.nes.loadRom(request.responseText)){
                            this.nes.start();
                            this.enable();
                        }
                      // Show a message on failure
                      } else {
                        updateStatus("Download of ROM failed. Make sure file exists and is a valid rom: \"" + url + "\".");
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
                
                void writeAudio(List<int> samples) {
                  return this.dynamicaudio.writeInt(samples);
                }
            
                void writeFrame(List<int> buffer) {
                    List<int> imageData = this.canvasImageData.data;
                    int pixel, i, j;

                    for (i=0; i<256*240; i++) {
                        pixel = buffer[i];

                        j = i*4;
                        imageData[j] = pixel & 0xFF;
                        imageData[j+1] = (pixel >> 8) & 0xFF;
                        imageData[j+2] = (pixel >> 16) & 0xFF;
                    }

                    this.canvasContext.putImageData(this.canvasImageData, 0, 0);
                }
            }

