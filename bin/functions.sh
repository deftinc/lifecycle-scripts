describe() {
  echo "--- $1…"
}

squelch() {
  $@ > /dev/null 2>&1
}

log_for() {
  mkdir -p ./tmp/logs/
  touch ./tmp/logs/$1.log
  printf "./tmp/logs/$1.log"
}

daemonize() {
  $@
}

check_port() {
  if lsof -n -i :$1 > /dev/null; then
    printf "\nError! port $1 is already being used.\n"
    exit 1
  fi
}

pid_for() {
  mkdir -p ./tmp/pids
  touch "./tmp/pids/$1.pid"
  printf "./tmp/pids/$1.pid"
}

check_pid() {
  PID_FILE=$(pid_for $1)
  if ps -p $(<$PID_FILE) > /dev/null; then
    printf "\n Error! $1 already running \n"
    exit 1
  fi
}

git_branch_name() {
  set +u
  if [ -n "$CI" ]; then
    local branch=$BUILDKITE_BRANCH
  else
    local branch=$(git rev-parse --abbrev-ref HEAD)
  fi
  set -u
  printf "$branch"
}

kill_pid() {
  PID_FILE=$(pid_for $1)
  if ps -p $(<$PID_FILE) > /dev/null; then
    kill $(<$PID_FILE) > /dev/null
    describe "Killed $1 ($(<$PID_FILE))"
  fi
}

phoenix_server() {
  check_port 4000
  check_pid phoenix
  LOG_FILE=$(log_for development)
  mix phx.server & > $LOG_FILE 2>&1
  echo $! > $(pid_for phoenix)
}

docker_services_up() {
  describe "Start docker services"
  docker-compose up -d
}

docker_services_down() {
  describe "Stop docker services"
  docker-compose down
}

brew_bundle_install() {
  if [ -f Brewfile ]; then
    brew bundle check || {
      describe "Install Homebrew dependencies"
      brew bundle
    }
  fi
}

npm_install_yarn() {
  [ -n "$(which yarn)" ] || {
    describe "Install yarn"
    npm install -g yarn
  }
}

elixir_install_hex_and_rebar() {
  describe "Install hex and rebar"
  mix local.hex --force
  mix local.rebar --force
}

asdf_bootstrap() {
  [ ! -d "$HOMEBREW_CELLAR/asdf" ] || {
    brew uninstall asdf
    describe "Uninstall asdf from homebrew"
  }
  [ -d "$HOME/.asdf" ] || {
    describe "Install asdf via git"
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf
    . $HOME/.asdf/asdf.sh
    echo '. $HOME/.asdf/asdf.sh' >> $HOME/.bash_profile
    asdf update
  }
}

asdf_add_plugins() {
  if [ -f .tool-versions ]; then
    describe "Add asdf language plugins"
    asdf plugin add nodejs || true
    asdf plugin add erlang || true
    asdf plugin add elixir || true
  fi
}

asdf_install_tools() {
  if [ -f .tool-versions ]; then
    describe ":elixir: :erlang: :nodejs: Install language versions"
    asdf install
  fi
}

asdf_update_plugins() {
  if [ -f .tool-versions ]; then
    describe "Update asdf language plugins"
    asdf plugin-update --all
  fi
}

docker_package() {
  local shortsha=$(git rev-parse --short HEAD)
  local longsha=$(git rev-parse HEAD)
  local branch=$(git_branch_name)
  local reponame="client/success"
  set +u
  if [[ -z "${NO_CACHE}" ]]; then
    set -u
    describe "Packaging via docker :docker:"
    docker build  --tag ${reponame}:${branch} .
  else
    set -u
    describe "Packaging via docker :docker: (No Cache)"
    docker build --no-cache --tag ${reponame}:${branch} .
  fi
  docker tag ${reponame}:${branch} ${reponame}:${shortsha}
  docker tag ${reponame}:${branch} ${reponame}:${longsha}
}

docker_publish() {
  local shortsha=$(git rev-parse --short HEAD)
  local longsha=$(git rev-parse HEAD)
  local branch=$(git_branch_name)
  local reponame="client/success"
  describe "Publishing to dockerhub :docker:"
  docker push ${reponame}:${branch}
  docker push ${reponame}:${longsha}
  docker push ${reponame}:${shortsha}
}

k8s_apply_manifests() {
  local kubecontext=$1
  local kubenamespace=$2
  local overlay=$3
  local longsha=$(git rev-parse HEAD)

  describe "Applying manifests ${overlay} :k8s:"
  cd $overlay
  kustomize edit set image success=client/success:${longsha}
  kustomize build . | kubectl --context ${kubecontext} --namespace ${kubenamespace}  apply -f -
  cd ../../
}

k8s_cluster_bootstrap() {
  describe "Cluster bootstrap :k8s:"
  local kubecontext="$1"

  kustomize build k8s/bootstrap --enable-helm | kubectl --context ${kubecontext} apply -f -
}

k8s_set_image() {
  local kubecontext=$1
  local kubenamespace=$2
  local longsha=$(git rev-parse HEAD)

  describe "Setting new image on deploy/success :k8s:"
  kubectl --context ${kubecontext} --namespace ${kubenamespace} set image deploy/success success=client/success:${longsha}
}

k8s_run_migrations() {
  local kubecontext=$1
  local kubenamespace=$2

  describe "Running database migrations :phoenix:"
  kubectl --context ${kubecontext} --namespace ${kubenamespace} rollout restart deploy/success
  kubectl --context ${kubecontext} --namespace ${kubenamespace} rollout status deploy/success --timeout=60s
  sleep 30
  kubectl --context ${kubecontext} --namespace ${kubenamespace} exec deploy/success -- /app/bin/migrate
}
