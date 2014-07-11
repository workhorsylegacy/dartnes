/*
DartNES Copyright (c) 2014 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
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
import 'dart:convert';
//import 'dart:web_audio';

import 'nes.dart';

// Returns true if running in JavaScript
// It works because JS uses doubles for integers
// Therefore in JS a 1 is the same as 1.0
bool isRunningInJavaScript() {
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
  ButtonInputElement pauseButton = null;
  ButtonInputElement restartButton = null;
  ButtonInputElement soundButton = null;
  int zoom = 1;
  static const int MAX_ZOOM = 6;
  var dynamicaudio = null;
  
  JSNES_UI() {
                // Tell the user if we are running in Dart or JS
                Element vm = querySelector('#vm');
                if(isRunningInJavaScript()) {
                  vm.innerHtml = "Using JavaScript VM";
                } else {
                  vm.innerHtml = "Using Dart VM";
                }
    
                this.status = querySelector('#status');
                this.parent = querySelector('#emulator');
    
                void status_cb(String m) => updateStatus(m);
                void frame_cb(List<int> bytes) => writeFrame(bytes);
                void audio_cb(List<int> samples) => writeAudio(samples);
                this.nes = new JSNES_NES(status_cb, frame_cb, audio_cb);
                
                /*
                 * Screen
                 */
                this.screen = querySelector('#screen');
                //this.screen.context2D.imageSmoothingEnabled = false;
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
                this.romSelect = querySelector('#romSelect');
                this.romSelect.onChange.listen((event) {
                    this.onLoadROM();
                });
                
                /*
                 * Buttons
                 */
                this.pauseButton = querySelector('#pause');
                this.restartButton = querySelector('#restart');
                this.soundButton = querySelector('#sound');

                this.pauseButton.onClick.listen((event) {
                    if (this.nes.isRunning) {
                        this.nes.stop();
                        this.updateStatus("Paused");
                        this.pauseButton.text = "resume";
                    } else {
                        this.nes.start();
                        this.pauseButton.text = "pause";
                    }
                });
        
                this.restartButton.onClick.listen((event) {
                    this.nes.reloadRom();
                    this.nes.start();
                });
        
                this.soundButton.onClick.listen((event) {
                    if (this.nes.opts['emulateSound']) {
                        this.nes.opts['emulateSound'] = false;
                        this.soundButton.text = "enable sound";
                    } else {
                        this.nes.opts['emulateSound'] = true;
                        this.soundButton.text = "disable sound";
                    }
                });

                window.onResize.listen((evt) {
                  this.onScreenResize();
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
                
                onLoadGameDatabse();
            }

            void onScreenResize() {
                  // Get the page width and height
                  int width = window.innerWidth;
                  int height = window.innerHeight;
                  
                  // Get the largest zoom we can fit
                  for(int i=1; i<=MAX_ZOOM; ++i) {
                      if(256 * i <= width && 240 * i <= height) {
                          this.zoom = i;
                      }
                  }

                  // Make the screen zoom
                  this.screen.style.width = (256 * this.zoom).toString() + "px";
                  this.screen.style.height = (240 * this.zoom).toString() + "px";          
            }
  
            void onReady() {
              onScreenResize();
              this.updateStatus("Ready to load a ROM.");
            }
  
            void onLoadGameDatabse() {
              this.updateStatus("Downloading Game Database ...");
              String url = Uri.encodeComponent("game_database.json");
              HttpRequest request = new HttpRequest();
              request.overrideMimeType('text/plain; charset=x-user-defined');
              request.onReadyStateChange.listen((_) {
                // Just return if not done yet
                if(request.readyState != HttpRequest.DONE)
                  return;
                
                // Load the rom on success
                if (request.status == 200) {
                  Map<String, Map<String, Object>> db = JSON.decode(request.responseText);
                  db.forEach((name, values) {
                      String file_name = values['file_name'];
                      bool is_broken = values['is_broken'];
                      if(file_name != null && !is_broken) {
                          OptionElement opt = new OptionElement(data: name, value: file_name, selected: false);
                          this.romSelect.children.add(opt);
                      }
                  });
                  this.onReady();
                // Show a message on failure
                } else {
                  this.updateStatus("Download of Game Database failed. Make sure file exists: \"" + url + "\".");
                }
              });
              
              request.open('GET', url);
              request.send();
            }
  
                void onLoadROM() {
                    this.updateStatus("Downloading ...");
                    String url = "local-roms/" + Uri.encodeComponent(this.romSelect.value);
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
                        this.updateStatus("Download of ROM failed. Make sure file exists and is a valid rom: \"" + url + "\".");
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
                    this.pauseButton.disabled = false;
                    if (this.nes.isRunning) {
                        this.pauseButton.text = "pause";
                    } else {
                        this.pauseButton.text = "resume";
                    }
                    this.restartButton.disabled = false;
                    if (this.nes.opts['emulateSound']) {
                        this.restartButton.text = "disable sound";
                    } else {
                        this.restartButton.text = "enable sound";
                    }
                }
            
                void updateStatus(String s) {
                    this.status.text = s;
                }
                
                void writeAudio(List<int> samples) {
                    this.dynamicaudio.writeInt(samples);
                }
            
                void writeFrame(List<int> buffer) {
                    List<int> imageData = this.canvasImageData.data;
                    int pixel, i, j;

                    for (i=0; i<256*240; ++i) {
                        pixel = buffer[i];

                        j = i*4;
                        imageData[j] = pixel & 0xFF;
                        imageData[j+1] = (pixel >> 8) & 0xFF;
                        imageData[j+2] = (pixel >> 16) & 0xFF;
                    }

                    this.canvasContext.putImageData(this.canvasImageData, 0, 0);
                }
            }

