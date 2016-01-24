

all:
	@echo make dart - Builds DartNES for browsers that understand Dart
	@echo make js - Builds DartNES for browser that understand JavaScript
	@echo make clean - Removes generated files

dart: clean
	@echo View the webpage at:
	@echo http://127.0.0.1:8000/index.html
	cd web; python -m SimpleHTTPServer 8000

js: clean
	/usr/lib/dart/bin/dart2js --out=web/source/main.dart.js web/source/main.dart
	@echo View the webpage at:
	@echo http://127.0.0.1:8000/index.html
	cd web; python -m SimpleHTTPServer 8000


clean:
	rm -f web/source/main.dart.js
	rm -f web/source/main.dart.js.deps
	rm -f web/source/main.dart.js.map
	rm -f web/source/main.dart.precompiled.js

