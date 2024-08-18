1. budowanie obrazu

`docker build -t iso-generator .`

w przypadku problemów `docker build --no-cache -t iso-generator .`

2. uruchamianie kontenera

`docker run --privileged -p 3000:3000  iso-generator`

3. Aplikacja będzie działać pod adresem `http://localhost:3000`. Po wejściu w przeglądarce zobaczymy aplikacje frontendową.
