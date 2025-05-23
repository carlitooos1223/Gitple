#! /bin/bash

# COLORS
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if [ ! -d .git ]; then
  echo -e "${RED}No te encuentras en un repositorio git${RESET}"
  exit
fi

readonly USAGE="Programa de control para tu repositorio Git.

Environment variables:

| Name            | Description                                                               |
|-----------------|---------------------------------------------------------------------------|
| GITUB_REPO      | Establece el nombre del repositorio de tu proyecto de Git.		      |
| GITHUB_OWNER    | Establece el nombre del propietario de tu GitHub.                         |
| GITHUB_TOKEN    | Establece el token de tu GitHub.                                          |

Usage:
  ${BLUE}gitple [command]${RESET}

Available Commands:
  ${GREEN}branch [show|create|delete]${RESET}       Lista tus branches | Crea una branch | Elimina una branch
  ${GREEN}commit${RESET}			    Realiza un commit con un mensaje automático
  ${GREEN}review${RESET}                            Muestra el estado de tu aplicación
  ${GREEN}start${RESET}                             Empezar un nuevo proyecto
  ${GREEN}tag [show|create|delete]${RESET}          Lista tus tags | Crea una tag | Elimina una tag
  ${GREEN}template [new|show|use]${RESET}           Crea una nueva plantilla | Lista todas tus plantillas generadas | Usa la plantilla creada
  ${GREEN}version [show|new]${RESET}                Te dice la última versión de tu aplicación | Crea una nueva versión y modifica el CHANGELOG automáticamente según tus commits

Flags:
  ${GREEN}-h, --help${RESET}                        Enseña ayuda sobre el comando.
  
${BLUE}Usa 'gitple <command> -h|--help' para obtener más información sobre el comando.${RESET}"

readonly SEMANTIC_RELEASE_VERSION="0.1.0"

readonly ERROR_MISSING_DEPS=1
readonly ERROR_ARGUMENTS=2
readonly ERROR_INVALID_REPOSITORY=3
readonly ERROR_GIT=4

readonly SEMVER_PATTERN="^v([0-9]+)\.([0-9]+)\.([0-9]+)$"
readonly FIX_PATTERN="^fix[:\(]"
readonly FEAT_PATTERN="^feat(\(.*\))?:"
readonly SUBJECT_PATTERN="^(feat|fix|docs|style|refactor|test|chore|perf)(\(.*\))?:"
readonly BREAKING_PATTERN="^BREAKING(\(.*\))?:"
readonly CLOSES_PATTERN="^closes\s(.+)"

readonly NO_BUMP=0
readonly PATCH_BUMP=1
readonly FEATURE_BUMP=2
readonly BREAKING_BUMP=3

dry_run=0
commit_messages=()
bump_type=$NO_BUMP
version=""
last_release_tag="" 
release_notes=""

shopt -s extglob

options() {
  if [ $# -eq 0 ]; then
    echo -e "$USAGE"
    exit
  fi
  while :; do
    case $1 in
      start)
        case $2 in
          -h|-\?|--help)
              help-start
              exit
              ;;
          *)
            if [ -z $2 ]; then
              echo -e "${GREEN}Iniciando un nuevo proyecto...${RESET}\n"
              echo "Introduce datos sobre tu proyecto:"
              read -p "Nombre del proyecto: " project_name
              read -p "Dueño/a del proyecto: " project_owner
              read -p "Token de Git: " token

              # ENVIROMENT VARIABLES
              touch "$HOME/.gitple/gitple_config_$project_name"
              config_file="$HOME/.gitple/gitple_config_$project_name"

              echo "GITHUB_OWNER=$project_owner" > "$config_file"
              echo "GITHUB_REPO=$project_name" >> "$config_file"
              echo "GITHUB_TOKEN=$token" >> "$config_file"

              source "$config_file"

              exit
            else
              echo "Comando desconocido: $2" >&2
              help-start
              exit "$ERROR_ARGUMENTS"
            fi
            ;;
        esac
        ;;
      commit)
        configure_env
        case $2 in
          -h|-\?|--help)
            help-commit
            exit
            ;;
          *)
            if [ -z $2 ]; then
              echo "Creando commit..."
              exit
            else
              echo "Comando desconocido: $2" >&2
              help-commit
              exit "$ERROR_ARGUMENTS"
            fi
            ;;
        esac
        ;;
      tag)
        configure_env
        case $2 in
          -h|-\?|--help|"")
            help-tag
            exit
            ;;
          show)
            echo -e "${GREEN}Mostrando tags...${RESET}"
            git tag --sort=-v:refname
            exit
            ;;
          create)
            if [[ "$3" == "-h" ]] || [[ "$3" == "--help" ]] || [[ "$3" == "" ]]; then
              echo "Usage: gitple tag create [nombre del tag]"
              echo "Descripción: crea un tag con el nombre especificado"
              exit
            elif [ -n "$3" ]; then
              check-tag-create "$3"
              if [ $existe_tag -eq 1 ]; then
                echo -e "${RED}Ya existe un tag con el nombre: $3${RESET}"
                exit
              else
                echo "Creando el tag: $3"
                create-tag "$3"
              fi
            fi
            ;;
          delete)
            if [[ "$3" == "-h" ]] || [[ "$3" == "--help" ]] || [[ "$3" == "" ]]; then
              echo "Usage: gitple tag delete [nombre del tag]"
              echo "Descripción: elimina el tag especificado"
              exit
            elif [ -n "$3" ]; then
              check-tag "$3"
              echo "Eliminando el tag: $3"
              delete-tag "$3"
            fi
            ;;
          *)
            echo "Comando desconocido: $2" >&2
            help-tag
            exit "$ERROR_ARGUMENTS"
            ;;
        esac
        ;;
      branch)
        configure_env
        case $2 in
          -h|-\?|--help|"")
            help-branch
            exit
            ;;
          show)
            echo -e "${GREEN}Mostrando branches...${RESET}"
            git branch
            exit
            ;;
          create)
            if [[ "$3" == "-h" ]] || [[ "$3" == "--help" ]] || [[ "$3" == "" ]]; then
              echo "Usage: gitple branch create [nombre de la branch]"
              echo "Descripción: crea una branch con el nombre especificado"
              exit
            elif [ -n "$3" ]; then
              check-branch-create "$3"
              if [ $existe_branch -eq 1 ]; then
                echo -e "${RED}Ya existe una branch con el nombre: $3${RESET}"
                exit
              else
                echo "Creando la branch: $3"
                create-branch "$3"
              fi
            fi
            exit
            ;;
          delete)
            if [[ "$3" == "-h" ]] || [[ "$3" == "--help" ]] || [[ "$3" == "" ]]; then
              echo "Usage: gitple branch delete [nombre de la branch]"
              echo "Descripción: elimina la branch especificada"
              exit
            elif [ -n "$3" ]; then
              check-branch "$3"
              echo "Eliminando la branch: $3"
              delete-branch "$3"
            fi
            exit
            ;;
          *)
            echo "Comando desconocido: $2" >&2
            help-branch
            exit "$ERROR_ARGUMENTS"
            ;;
        esac
        ;;
      template)
        configure_env
        case $2 in
          -h|-?\|--help)
            help-template
            exit
            ;;
          new)
            read -p "Nombre de la plantilla: " new_template
            echo "Creando plantilla"

            mkdir -p "$HOME/.gitple/templates/$new_template"
            find . -mindepth 1 ! -name ".git" ! -path "./.git/*" -exec cp -r --parents {} "$HOME/.gitple/templates/$new_template/" \;

            echo "Plantilla: $new_template guardada correctamente"
            exit
            ;;
          show)
            ls_template=$(ls $HOME/.gitple/templates/ | wc -l)

            templates=()
            show_templates=$(ls $HOME/.gitple/templates/)

            if [ $ls_template -eq 0 ]; then
              echo "${RED}Actualmente no tienes ninguna plantilla creada${RESET}"
              echo -e "Para crear una nueva utilice: ${BLUE}gitple template new${RESET}"
            else
              for template in $show_templates; do
                pos=${#templates[@]}
                templates[$pos]=$template
              done

              echo "Estas son tus plantillas:"
              echo -e ${GREEN}${templates[@]}${RESET}
            fi
            exit
            ;;
          use)
            template=$3

            if [ -z $template ]; then
              echo -e "Debes añadir el nombre de la plantilla que quieras utilizar"
              echo -e "Para listar tus plantillas utilice: ${BLUE}gitple template show${RESET}"
              echo
              echo -e "${BLUE}Usage: gitple use [nombre de la plantilla]"
            else
              if [ -d $HOME/.gitple/templates/$template ]; then
                read -p "Nombre del nuevo repositorio: " new_repo
                cp -r $HOME/.gitple/templates/$template/ ../$new_repo
                echo -e "Se ha creado el repositorio: ${BLUE}$new_repo${RESET} con la plantilla: ${BLUE}use_template${RESET}"
              else
                echo "La plantilla $template no existe"
                echo -e "Si quieres crear una nueva plantilla utilice: ${BLUE}gitple template new${RESET}"
              fi
            fi
            exit
            ;;
          *)
            echo "Comando desconocido: $2" >&2
            help-template
            exit "$ERROR_ARGUMENTS"
            ;;
        esac
        ;;
      version)
        configure_env
        case $2 in
          -h|-\?|--help)
            help-version
            exit
            ;;
          show)
            version
            exit
            ;;
          new)
            semantic_release
            exit
            ;;
          *)
            echo "Comando desconocido: $2" >&2
            help-version
            exit "$ERROR_ARGUMENTS"
            ;;
        esac
        ;;
      review)
        configure_env
        case $2 in
          -h|-\?|--help)
            help-review
            exit
            ;;
          *)
            if [ -z $2 ]; then
              echo -e "${GREEN}Estado de tu proyecto${RESET}\n"
              echo -e "${BLUE}Descripción:${RESET}"
              echo -e "Nombre del proyecto: $GITHUB_REPO"
              echo -e "Dueño/a del proyecto: $GITHUB_OWNER \n"

              echo -e "${BLUE}Archivos esenciales:${RESET}"
              check_files
              if [ ${#files[@]} -eq 0 ]; then
                echo -e "Todos los archivos esenciales están presentes ${GREEN}CORRECTO${RESET}"
              else
                echo "Faltan los siguientes archivos esenciales:"
                for file in "${files[@]}"; do
                  echo "- $file"
                done
              fi

              echo -e "\n${BLUE}Dependencias:${RESET}"
              review-dependencies
              exit
            else
              echo "Comando desconocido: $1" >&2
              help-review
              exit "$ERROR_ARGUMENTS"
            fi
            ;;
        esac
        ;;
      -h|-\?|--help)
        echo -e "$USAGE"
        exit
        ;;
      -?*)
        echo "Comando desconocido: $1" >&2
        echo -e "$USAGE"
        exit "$ERROR_ARGUMENTS"
        ;;
      ?*)
        echo "Comando desconocido: $1" >&2
        echo -e "$USAGE"
        exit "$ERROR_ARGUMENTS"
        ;;
    esac
  done
}

help-start() {
  echo -e "
  Este comando es obligatorio para empezar a utilizar el programa.
  Se deberá utilizar en un repositorio de git.

  Pedirá 3 variables de entrono:
    ${GREEN}GITHUB_REPO${RESET}                    Nombre de tu repositorio de Github
    ${GREEN}GITHUB_OWNER${RESET}                   Propietario del repositorio    
    ${GREEN}GITHUB_TOKEN${RESET}                   Token de la cuenta de Github

  ${BLUE}Usage: git start${RESET}"
}

help-commit() {
  echo -e "
  Description: Generará automáticamente un commit con los cambios realizados.
  
  ${BLUE}Usage: gitple commit${RESET}"
}

help-template() {
  echo -e "
  Description: 
    Creará una plantilla a partir de los directorios y ficheros de tu repositorio.

    Solo crea un repositorio igual, no se establecen las variables de entorno, 
    para utilizar el repositorio creado con la plantilla, utilice dentro: ${BLUE}gitple start${RESET}

  Avaible commands:
    ${GREEN}new${RESET}         Crea una nueva plantilla
    ${GREEN}show${RESET}        Lista todas tus plantillas generadas
    ${GREEN}use${RESET}         Usa la plantilla creada

  ${BLUE}Usage: gitple template [new|show|use]${RESET}"

}

help-tag() {
  echo -e "
  ${BLUE}Usage: gitple tag [option]${RESET}

  Available Commands:
    ${GREEN}show${RESET}                         Lista tus branches
    ${GREEN}create${RESET}                       Crea una branch
    ${GREEN}delete${RESET}                       Elimina una branch"
}

help-branch() {
  echo -e "
  ${BLUE}Usage: gitple branch [option]${RESET}

  Available Commands:
    ${GREEN}show${RESET}                         Lista tus branches
    ${GREEN}create${RESET}                       Crea una branch
    ${GREEN}delete${RESET}                       Elimina una branch"
}

help-version() {
  echo -e "
  ${BLUE}Usage: gitple version [show|version]${RESET}"

}

help-review () {
  echo -e "
  Muestra el estado de tu aplicación.

  Essential files:
    ${GREEN}README.md${RESET}                     Archivo de documentación
    ${GREEN}CHANGELOG.md${RESET}                  Archivo de cambios de versión
    ${GREEN}LICENSE${RESET}                       Archivo de licencia

    ${BLUE}Description: Chequea si tienes 3 de los archivos más esenciales para tu proyecto.${RESET}

  Available dependencies:
    ${GREEN}requirements.txt${RESET}              Dependencias de Python
    ${GREEN}package.json${RESET}                  Dependencias de Nodejs
    ${GREEN}commposer.json${RESET}                Dependencias de PHP

    ${BLUE}Description: Hace un chequeo para ver si tu proyecto tiene las dependencias actualizadas.${RESET}
  
  Security:
    ${BLUE}Description: Revisa si todos los ficheros por si tienes algo importante sin descrifrar o que pueda comprometer a tu repositorio.${RESET}

  Usage: 
    ${BLUE}gitple review${RESET}"
}

show-tags() {
    git tag --sort=-v:refname
    exit
}

check-tag() {
  tag=$1

  local_tag=$(git tag | grep "$tag" | wc -l)
  remote_tag=$(git ls-remote --tags origin | grep "$tag" | wc -l)
  if [ $local_tag -eq 0 ] && [ $remote_tag -eq 0 ]; then
    echo "El tag proporcionado no existe: $tag"
    echo
    echo Para listar tus tags utilice: gitple show tags
    exit
  fi
}

check-tag-create() {
  tag=$1

  local_tag=$(git tag | grep "$tag" | wc -l)
  remote_tag=$(git ls-remote --tags origin | grep "$tag" | head -n1 | wc -l)

  if [ $local_tag -eq 1 ] && [ $remote_tag -eq 1 ]; then
    existe_tag=1
  else
    existe_tag=0
  fi
}

create-tag() {
  tag=$1

  git tag -a $tag -m "Tag $tag"
  git push origin $tag > /dev/null 2>&1
  exit
}

delete-tag() {
  tag=$1

  git tag -d $tag
  git push origin --delete $tag > /dev/null 2>&1
  exit
}

check-branch() {
    branch=$1
    
    local_branch=$(git branch | grep "$branch" | wc -l)
    remote_branch=$(git ls-remote --heads origin | grep "$branch" | wc -l)
    if [ $local_branch -eq 0 ] && [ $remote_branch -eq 0 ]; then
        echo "El branch proporcionado no existe: $branch"
        echo
        echo Para listar tus branches utilice: gitple branch show
        exit
    fi
}

check-branch-create() {
    branch=$1

    local_branch=$(git branch | grep "$branch" | wc -l)
    remote_branch=$(git ls-remote --heads origin | grep "$branch" | head -n1 | wc -l)

    if [ $local_branch -eq 1 ] && [ $remote_branch -eq 1 ]; then
        existe_branch=1
    else
        existe_branch=0
    fi
}

create-branch() {
    branch=$1

    git branch $branch
    git push origin $branch > /dev/null 2>&1
    exit
}

delete-branch() {
    branch=$1
    
    git branch -d $branch
    git push origin --delete $branch > /dev/null 2>&1
    exit
}

version() {
  if [ ! -f info/last_version.txt ]; then
    echo "Actualmente tu aplicación no tiene ninguna versión disponible"
    echo "Para crear una nueva versión ejecute: gitple new-version"
  else
    echo -e "${GREEN}La versión más reciente encontrada es:${RESET}
    cat info/last_version.txt
  fi
}

check_files() {
  files=()
  pos=${#files[@]}

  if [ ! -f "README.md" ]; then
    files[$pos]="README.md"
    pos=${#files[@]}
  fi
  if [ ! -f "CHANGELOG.md" ]; then
    files[$pos]="CHANGELOG.md"
    pos=${#files[@]}
  fi
  if [ ! -f "LICENSE" ]; then
    files[$pos]="LICENSE"
    pos=${#files[@]}
  fi
}

review-dependencies() {
  no_dependencias=0

  if [ ! -f "requirements.txt" ]; then
    no_dependencias=$((no_dependencias+1))
  else
    dependencia="python"
  fi
  if [ ! -f "package.json" ]; then
    no_dependencias=$((no_dependencias+1))
  else
    dependencia="nodejs"
  fi
  if [ ! -f composer.json ]; then
    no_dependencias=$((no_dependencias+1))
  else
    dependencia="php"
  fi
  if [ $no_dependencias -eq 3 ]; then
    echo -e "Tu proyecto no necesita dependencias ${GREEN}CORRECTO${RESET}"
  else
    if [[ "$dependencia" == "python" ]]; then
      python_dependencia
    elif [[ "$dependencia" == "nodejs" ]]; then
      nodejs_dependencia
    elif [[ "$dependencia" == "php" ]]; then
      php_dependencia
    fi
  fi
}

check_dependencies() {
  for cmd in "$@"; do
    if ! command -v "$cmd" > /dev/null ; then
      echo "$cmd command not found"
      exit $ERROR_MISSING_DEPS
    fi
  done
}

find_last_release_tag() {
  local tags sorted
  tags=()
  if ! output=$(git tag --sort=-v:refname 2>&1); then
    echo "Not a git repository" >&2
    exit $ERROR_INVALID_REPOSITORY
  fi

  while read -r tag ; do
    if [[ "$tag" =~ $SEMVER_PATTERN ]] &&
      git merge-base --is-ancestor "$tag" HEAD 2>/dev/null; then 
      tags+=("$tag")
    fi
  done <<< "$output"

  if [[ ${#tags[@]} -eq 0 ]]; then
    echo "No se encontró ninguna etiqueta, estableciendo v0.1.0"
    last_release_tag="v0.1.0"
  else
    last_release_tag="${tags[0]}"
  fi
}

read_commit_messages() {
  local from range
  from="$1"
  commit_messages=()

  if [[ -z "$from" || "$from" == "v0.1.0" ]]; then 
    from=$(git rev-list --max-parents=0 HEAD)
    range="${from}..HEAD"
  else
    from=$(git rev-parse "$from") 
    range="${from}..HEAD"
  fi

  while IFS=$'\x1f' read -r -d $'\x1e' commit_id commit; do
    commit=${commit%%$'\n'}
    commit=${commit##$'\n'} 
    commit_messages+=("${commit} ${commit_id}")
  done < <(git log --pretty=format:'%h%x1f%B%x1e' "$range")
}

declare -A categorized_changes=(
  [feat]=""
  [fix]=""
  [docs]=""
  [style]=""
  [refactor]=""
  [test]=""
  [chore]=""
  [perf]=""
  [breaking]=""
)

append_changelog() {
  local commit first subject refs closes type 
  commit="$1"
  commit_id="$2"
  first=1
  refs=()

  while read -r line ; do
    if [[ "$first" -eq 1 ]]; then
      subject="$line"
      if [[ "$subject" =~ $SUBJECT_PATTERN ]]; then
        type="${BASH_REMATCH[1]}"
      else
        type="other"
      fi
    fi

    if [[ "$first" -ne 1 ]] && [[ "${line,,}" =~ $CLOSES_PATTERN ]]; then
      IFS=', '
      read -r -a array <<< "${BASH_REMATCH[1]}"
      refs+=("${array[@]}")
    fi

    first=0
  done <<< "$commit"

  if [[ ${#refs[@]} -ne 0 ]]; then
    IFS=','; closes=" (${refs[*]})"
  else
    closes=""
  fi

  type=${type,,}
  categorized_changes[$type]+="$subject$closes\n"
}

update_bump_type() {
  local commit bump first
  commit="$1"
  bump=$NO_BUMP
  first=1

  while read -r line; do
    if [[ "$first" -eq 1 ]] && [[ "$line" =~ $FIX_PATTERN ]]; then
      bump=$PATCH_BUMP
    fi
    if [[ "$first" -eq 1 ]] && [[ "$line" =~ $FEAT_PATTERN ]]; then
        bump=$FEATURE_BUMP
    fi
    if [[ "$first" -eq 1 ]] && [[ "$line" =~ $BREAKING_PATTERN ]]; then
        bump=$BREAKING_BUMP
    fi
    first=0
  done <<< "$commit"

  if [[ "$bump" -gt "$bump_type" ]]; then
    bump_type="$bump"
  fi
}

analyze_commit_messages() {
  declare -gA categorized_changes=(
    [feat]=""
    [fix]=""
    [docs]=""
    [style]=""
    [refactor]=""
    [test]=""
    [chore]=""
    [perf]=""
    [BREAKING]=""
  )
  bump_type=$NO_BUMP

  for commit_message in "$@" ; do
    commit_id=$(echo $commit_message | cut -d' ' -f2)
    commit=$(echo $commit_message | cut -d' ' -f1-)
    append_changelog "$commit" $commit_id
    update_bump_type "$commit_message"
  done
}

bump_version() {
  local bump last_version major minor patch
  bump="$1"
  last_version="$2"
  version=""

  if [[ "$last_version" =~ $SEMVER_PATTERN ]] ; then
    major=${BASH_REMATCH[1]}
    minor=${BASH_REMATCH[2]}
    patch=${BASH_REMATCH[3]}
    if [[ "$bump" == "$PATCH_BUMP" ]] ; then
      patch=$((patch+1))
    fi
    if [[ "$bump" == "$FEATURE_BUMP" ]] ; then
      minor=$((minor+1))
      patch=0
    fi
    if [[ "$bump" == "$BREAKING_BUMP" ]] ; then
      major=$((major+1))
      minor=0
      patch=0
    fi
    version="v${major}.${minor}.${patch}"
  fi
}

build_release_notes() {
  release_notes=""
  for type in feat fix docs style refactor test chore perf; do
    local entries="${categorized_changes[$type]}"
    if [[ -n "$entries" ]]; then
      release_notes+="### ${type^}\n"
      while IFS= read -r line; do
        [[ -n "$line" ]] && release_notes+="* $line\n"
      done <<< "$(echo -e "$entries")"
      release_notes+="\n"
    fi
  done
  release_notes=${release_notes//$'\n'/\\n}
  release_notes=${release_notes//\"/\\\"}
}

create_gitlab_tag() {
  local githead data url outfile status
  githead=$(git rev-parse HEAD)
  data="{
    \"ref\": \"refs/tags/${version}\",
    \"sha\": \"${githead}\"
  }"
  url="https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/git/refs"

  outfile=$(mktemp)
  trap '{ rm -f "$outfile"; }' EXIT

  status=$(curl \
      --silent \
      -X POST \
      --output "$outfile" \
      --write-out "%{http_code}" \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Content-Type: application/json" \
      --data "$data" \
      "$url")

  echo "$status" > /dev/null 2>&1

  if [[ $? -ne 0 || "$status" -ge 300 ]]; then
      echo "Error creando tag en GitHub:" >&2
      echo "curl exit code: $?" >&2
      echo "HTTP Status: $status" >&2
      echo "HTTP Request:" >&2
      echo "$data"
      echo "HTTP Response:" >&2
      cat "$outfile" >&2
      echo
      echo "ENTRANDO EN IF"
      exit "$ERROR_GIT"
  fi

  git push origin $version > /dev/null 2>&1
}

create_git_tag() {
  local output
  if ! output=$(git tag -m "Semantic release $version" "$version"); then
    echo "Error creating tag in local git repository:" >&2
    echo "git exit code: $?" >&2
    echo "git output:" >&2
    echo "$output" >&2
    exit "$ERROR_GIT"
  fi
  echo "Tag created in local git repository" >&2
}

create_tag() {
  if [[ -n $GITHUB_TOKEN ]]; then
    create_gitlab_tag
  else
    echo "Environment variable GITHUB_TOKEN not provided." >&2
    create_git_tag
  fi
}

get_versions() {
  declare -A versions
  local tag major minor patch

  for tag in $(git tag --sort=-v:refname); do
    if [[ "$tag" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
      major="${BASH_REMATCH[1]}"
      minor="${BASH_REMATCH[2]}"
      patch="${BASH_REMATCH[3]}"

      versions["$major,$minor"]="$tag"
    fi
  done

  echo "${!versions[@]}"
}

semantic_release() {
  check_dependencies git curl
  find_last_release_tag
  read_commit_messages "$last_release_tag"
  analyze_commit_messages "${commit_messages[@]}"

  if [[ "$bump_type" -eq "$NO_BUMP" ]]; then
    echo "No changes since last release" >&2 
    return
  else
    if [[ -z "$last_release_tag" ]]; then
      version="v0.1.0"
    else
      bump_version "$bump_type" "$last_release_tag"
    fi
    build_release_notes 

    date=$(date "+%Y-%m-%d")

    # Create necessary files
    if [ ! -d "info" ]; then
      mkdir info
    fi
    touch info/app_version.txt
    touch info/last_version.txt
    touch info/new_version.txt
    touch info/title.txt

    url_versiones="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/tree"

    # Create the changelog
    echo -e "# CHANGELOG \nAll notable changes to this project will be documented in this file." > info/title.txt
    echo -e "## [$version]($url_versiones/$version) - $date\n" | tee info/new_version.txt
    echo -e "$(echo -e "$release_notes")" | tee -a info/new_version.txt

    cat info/new_version.txt info/app_version.txt > temp && mv temp info/app_version.txt 
    cat info/title.txt info/app_version.txt > CHANGELOG.md

    echo $version > info/last_version.txt

    # Create the new tag in the local repository
    if ! git tag | grep "^$version" ; then
      git tag $version;
      echo "Tag $version creado";
    else
      echo "Tag $version ya existe, no se hace nada"; 
    fi

    bump_version "$bump_type" "$last_release_tag"

    if [[ "$dry_run" -eq 1 ]]; then
      echo "Dry run. Tag not created."
    else
      create_tag
    fi
  fi
}

# Configuración de las variables de entorno
configure_env() {
  nombre=$(basename "$PWD")
  inicio=$(find / -name ".gitple_config_$nombre" | wc -l)

  if [ $inicio -eq 1 ]; then
    source "$HOME/.gitple/gitple_config_$nombre"
  else
    echo -e "No se ha encontrado ningún archivo de configuración para este proyecto\n"
    echo -e "${BLUE}Para iniciar el proyecto utilice: gitple start${RESET}"
    exit
  fi
}

options "$@"
