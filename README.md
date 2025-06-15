# Gitple - Gestor de repositorios de Git
## 🔹 Descripción
Gitple es una herramienta en **Bash** diseñada para simplificar la gestión de proyectos Github. <br>

Con este programa te será más fácil la organización de tu repositorio, funciones como creador de plantillas, generador de CHANGELOG automático, commits automáticos generados con IA, entre más funciones que puedes utilizar.

## 🔹 Instalación
Ejecuta el siguiente comando para descargar el archivo `.deb` de **gitple** desde GitHub:
```bash
wget https://github.com/carlitooos1223/Gitple/releases/download/v1.0.0/Gitple.deb
```

Para ejecutar el paquete de **gitple** ejecuta lo siguiente:
```bash
sudo dpkg -i gitple.deb
```

## 🔹 Uso de Gitple
Gitple solo se podrá utilizar en repositorios de git, y para iniciar la aplicación en un repositorio nuevo deberá utilizar:
``` bash
gitple start
````

Para utilizar el programa será tan facíl como: `gitple <command>`

En caso de necesitar ayuda con algún comando utilice la flag `-h` | `--help`

### Dependencias
Para utilizar ciertas funciones del programa es necesario instalar los paquetes `curl` y `jq`.
Al ejecutar el comando en concreto te dirá si tienes o no instalado el paquete necesario, y te preguntará si quieres instalarlo en tu sistema.
