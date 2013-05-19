

all: clean
	dart2js --out=web/source/main.dart.js web/source/main.dart
	firefox http://localhost:8000/dartnes.html
	cd web; python -m SimpleHTTPServer


clean:
	rm -f web/source/main.dart.js
	rm -f web/source/main.dart.js.deps
	rm -f web/source/main.dart.js.map

