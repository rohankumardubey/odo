#!/usr/bin/env bash

# A set of helpers for starting/running etcd for tests

ETCD_VERSION=${ETCD_VERSION:-3.2.16}
ETCD_HOST=${ETCD_HOST:-127.0.0.1}
ETCD_PORT=${ETCD_PORT:-2379}
export KUBE_INTEGRATION_ETCD_URL="https://${ETCD_HOST}:${ETCD_PORT}"

kube::etcd::validate() {
  # validate if in path
  command -v etcd >/dev/null || {
    kube::log::usage "etcd must be in your PATH"
    kube::log::info "You can use 'hack/install-etcd.sh' to install a copy in third_party/."
    exit 1
  }

  # validate etcd port is free
  local port_check_command
  if command -v ss &> /dev/null && ss -Version | grep 'iproute2' &> /dev/null; then
    port_check_command="ss"
  elif command -v netstat &>/dev/null; then
    port_check_command="netstat"
  else
    kube::log::usage "unable to identify if etcd is bound to port ${ETCD_PORT}. unable to find ss or netstat utilities."
    exit 1
  fi
  if ${port_check_command} -nat | grep "LISTEN" | grep "[\.:]${ETCD_PORT:?}" >/dev/null 2>&1; then
    kube::log::usage "unable to start etcd as port ${ETCD_PORT} is in use. please stop the process listening on this port and retry."
    kube::log::usage "`netstat -nat | grep "[\.:]${ETCD_PORT:?} .*LISTEN"`"
    exit 1
  fi

  # validate installed version is at least equal to minimum
  version=$(etcd --version | tail -n +1 | head -n 1 | cut -d " " -f 3)
  if [[ $(kube::etcd::version $ETCD_VERSION) -gt $(kube::etcd::version $version) ]]; then
   hash etcd
   echo $PATH
   version=$(etcd --version | head -n 1 | cut -d " " -f 3)
   if [[ $(kube::etcd::version $ETCD_VERSION) -gt $(kube::etcd::version $version) ]]; then
    kube::log::usage "etcd version ${ETCD_VERSION} or greater required."
    kube::log::info "You can use 'hack/install-etcd.sh' to install a copy in third_party/."
    exit 1
   fi
  fi
}

kube::etcd::version() {
  printf '%s\n' "${@}" | awk -F . '{ printf("%d%03d%03d\n", $1, $2, $3) }'
}

kube::etcd::start() {
  # validate before running
  kube::etcd::validate

  # Start etcd
  ETCD_DIR=${ETCD_DIR:-$(mktemp -d 2>/dev/null || mktemp -d -t test-etcd.XXXXXX)}
  if [[ -d "${ARTIFACTS_DIR:-}" ]]; then
    ETCD_LOGFILE="${ARTIFACTS_DIR}/etcd.$(uname -n).$(id -un).log.DEBUG.$(date +%Y%m%d-%H%M%S).$$"
  else
    ETCD_LOGFILE=${ETCD_LOGFILE:-"/dev/null"}
  fi
  kube::log::info "etcd --advertise-client-urls ${KUBE_INTEGRATION_ETCD_URL} --data-dir ${ETCD_DIR}/data --listen-client-urls http://${ETCD_HOST}:${ETCD_PORT} --debug > \"${ETCD_LOGFILE}\" 2>/dev/null"
  etcd --advertise-client-urls ${KUBE_INTEGRATION_ETCD_URL} --cert-file=${ETCD_DIR}/serving-etcd-server.crt --key-file=${ETCD_DIR}/serving-etcd-server.key --data-dir ${ETCD_DIR}/data --listen-client-urls ${KUBE_INTEGRATION_ETCD_URL} --debug 2> "${ETCD_LOGFILE}" >/dev/null &
  ETCD_PID=$!

  echo "Waiting for etcd to come up."
  kube::util::wait_for_url "${KUBE_INTEGRATION_ETCD_URL}/version" "etcdserver" 0.25 80
}

kube::etcd::stop() {
  if [[ -n "${ETCD_PID-}" ]]; then
    kill "${ETCD_PID}" &>/dev/null || :
    wait "${ETCD_PID}" &>/dev/null || :
  fi
}

kube::etcd::clean_etcd_dir() {
  if [[ -n "${ETCD_DIR-}" ]]; then
    rm -rf "${ETCD_DIR}/data"
  fi
}

kube::etcd::cleanup() {
  kube::etcd::stop
  kube::etcd::clean_etcd_dir
}
